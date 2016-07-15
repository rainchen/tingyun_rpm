# encoding: utf-8

require 'ting_yun/support/helper'
module TingYun
  module Agent
    module Database

      MAX_QUERY_LENGTH = 16384

      extend self


      def obfuscate_sql(sql)
        Obfuscator.instance.obfuscator.call(sql)
      end


      def capture_query(query)
        TingYun::Helper.correctly_encoded(truncate_query(query))
      end

      def truncate_query(query)
        if query.length > (MAX_QUERY_LENGTH - 4)
          query[0..MAX_QUERY_LENGTH - 4] + '...'
        else
          query
        end
      end


      RECORD_FOR = [:raw, :obfuscated].freeze

      def should_record_sql?(key)
        RECORD_FOR.include?(record_sql_method(key.to_sym))
      end

      def record_sql_method(key)

        case Agent.config[key].to_s
          when 'off'
            :off
          when 'raw'
            :raw
          else
            :obfuscated
        end
      end

      def should_action_collect_explain_plans?
        should_record_sql?("nbs.action_tracer.record_sql") &&
            Agent.config["nbs.action_tracer.explain_enabled".to_sym]
      end

      def explain_sql(sql, config, explainer=nil)
        return nil unless sql && explainer && config
        _sql = sql.split(";\n")[0] # only explain the first
        explain_plan = explain(_sql, config, explainer)
        return explain_plan || {"dialect"=> nil, "keys"=>[], "values"=>[]}
      end

      SUPPORTED_ADAPTERS_FOR_EXPLAIN = %w[postgres postgresql mysql2 mysql sqlite].freeze

      def explain(sql, config, explainer=nil)

        return unless explainer && is_select?(sql)

        if sql[-3,3] == '...'
          TingYun::Agent.logger.debug('Unable to collect explain plan for truncated query.')
          return
        end

        if parameterized?(sql)
          TingYun::Agent.logger.debug('Unable to collect explain plan for parameterized query.')
          return
        end

        adapter = adapter_from_config(config)
        if !SUPPORTED_ADAPTERS_FOR_EXPLAIN.include?(adapter)
          TingYun::Agent.logger.debug("Not collecting explain plan because an unknown connection adapter ('#{adapter}') was used.")
          return
        end

        handle_exception_in_explain do
          plan = explainer.call(config, sql)
          return process_resultset(plan, adapter) if plan
        end
      end

      def adapter_from_config(config)
        if config[:adapter]
          return config[:adapter].to_s
        elsif config[:uri] && config[:uri].to_s =~ /^jdbc:([^:]+):/
          # This case is for Sequel with the jdbc-mysql, jdbc-postgres, or
          # jdbc-sqlite3 gems.
          return $1
        end
      end


      def parameterized?(sql)
        Obfuscator.instance.obfuscate_single_quote_literals(sql) =~ /\$\d+/
      end

      def is_select?(sql)
        parse_operation_from_query(sql) == 'select'
      end

      def process_resultset(results ,adapter)
        case adapter.to_s
          when 'postgres', 'postgresql'
            process_explain_results_postgres(results)
          when 'mysql2'
            process_explain_results_mysql2(results)
          when 'mysql'
            process_explain_results_mysql(results)
          when 'sqlite'
            process_explain_results_sqlite(results)
        end
      end

      QUERY_PLAN = 'QUERY PLAN'.freeze

      def process_explain_results_postgres(results)
        if results.is_a?(String)
          query_plan_string = results
        else
          lines = []
          results.each { |row| lines << row[QUERY_PLAN] }
          query_plan_string = lines.join("\n")
        end

        unless record_sql_method(:"nbs.action_tracer.record_sql") == :raw
          query_plan_string = Obfuscator.instance.obfuscate_postgres_explain(query_plan_string)
        end
        values = query_plan_string.split("\n").map { |line| [line] }

        {"dialect"=> "PostgreSQL", "keys"=>[QUERY_PLAN], "values"=>values}
      end

      def string_explain_plan_results(adpater, results)
        {"dialect"=> adpater, "keys"=>[], "values"=>[results]}
      end

      def process_explain_results_mysql2(results)
        return string_explain_plan_results("MySQL", results) if results.is_a?(String)
        headers = results.fields
        values  = []
        results.each { |row| values << row }
        {"dialect"=> "MySQL", "keys"=>headers, "values"=>values}
      end

      def process_explain_results_mysql(results)
        return string_explain_plan_results("MySQL", results) if results.is_a?(String)
        headers = []
        values  = []
        if results.is_a?(Array)
          # We're probably using the jdbc-mysql gem for JRuby, which will give
          # us an array of hashes.
          headers = results.first.keys
          results.each do |row|
            values << headers.map { |h| row[h] }
          end
        else
          # We're probably using the native mysql driver gem, which will give us
          # a Mysql::Result object that responds to each_hash
          results.each_hash do |row|
            headers = row.keys
            values << headers.map { |h| row[h] }
          end
        end
        {"dialect"=> "MySQL", "keys"=>headers, "values"=>values}
      end

      SQLITE_EXPLAIN_COLUMNS = %w[addr opcode p1 p2 p3 p4 p5 comment]

      def process_explain_results_sqlite(results)
        return string_explain_plan_results("sqlite", results) if results.is_a?(String)
        headers = SQLITE_EXPLAIN_COLUMNS
        values  = []
        results.each do |row|
          values << headers.map { |h| row[h] }
        end
        {"dialect"=> "sqlite", "keys"=>headers, "values"=>values}
      end



      KNOWN_OPERATIONS = [
          'alter',
          'select',
          'update',
          'delete',
          'insert',
          'create',
          'show',
          'set',
          'exec',
          'execute',
          'call'
      ]

      SQL_COMMENT_REGEX = Regexp.new('/\*.*?\*/', Regexp::MULTILINE).freeze
      EMPTY_STRING      = ''.freeze

      def parse_operation_from_query(sql)
        sql = TingYun::Helper.correctly_encoded(sql).gsub(SQL_COMMENT_REGEX, EMPTY_STRING)
        if sql =~ /(\w+)/
          op = $1.downcase
          return op if KNOWN_OPERATIONS.include?(op)
        end
      end


      def handle_exception_in_explain
        yield
      rescue => e
        ::TingYun::Agent.logger.error("Error getting query plan:", e)
        nil
      end


      def get_connection(config, &connector)
        ConnectionManager.instance.get_connection(config, &connector)
      end

      def close_connections
        ConnectionManager.instance.close_connections
      end

      # Returns a cached connection for a given ActiveRecord
      # configuration - these are stored or reopened as needed, and if
      # we cannot get one, we ignore it and move on without explaining
      # the sql
      class ConnectionManager
        include Singleton

        def get_connection(config, &connector)
          @connections ||= {}

          connection = @connections[config]

          return connection if connection

          begin
            @connections[config] = connector.call(config)
          rescue => e
            ::TingYun::Agent.logger.error("Caught exception trying to get connection to DB for explain.", e)
            nil
          end
        end

        # Closes all the connections in the internal connection cache
        def close_connections
          @connections ||= {}
          @connections.values.each do |connection|
            begin
              connection.disconnect!
            rescue
            end
          end

          @connections = {}
        end
      end

      class Statement
        attr_accessor :sql, :config, :explainer

        def initialize(sql, config={}, explainer=nil)
          @sql = TingYun::Agent::Database.capture_query(sql)
          @config = config
          @explainer = explainer
        end

        def adapter
          config && config[:adapter]
        end
      end

      #混淆器
      class Obfuscator
        include Singleton

        attr_reader :obfuscator

        def initialize
          reset
        end

        def reset
          @obfuscator = method(:default_sql_obfuscator)
        end

        QUERY_TOO_LARGE_MESSAGE     = "Query too large (over 16k characters) to safely obfuscate"
        FAILED_TO_OBFUSCATE_MESSAGE = "Failed to obfuscate SQL query - quote characters remained after obfuscation"

        def default_sql_obfuscator(sql)
          stmt = sql.kind_of?(Statement) ? sql : Statement.new(sql)

          if stmt.sql[-3,3] == '...'
            return QUERY_TOO_LARGE_MESSAGE
          end

          obfuscate_double_quotes = stmt.adapter.to_s !~ /postgres|sqlite/

          obfuscated = obfuscate_numeric_literals(stmt.sql)

          if obfuscate_double_quotes
            obfuscated = obfuscate_quoted_literals(obfuscated)
            obfuscated = remove_comments(obfuscated)
            if contains_quotes?(obfuscated)
              obfuscated = FAILED_TO_OBFUSCATE_MESSAGE
            end
          else
            obfuscated = obfuscate_single_quote_literals(obfuscated)
            obfuscated = remove_comments(obfuscated)
            if contains_single_quotes?(obfuscated)
              obfuscated = FAILED_TO_OBFUSCATE_MESSAGE
            end
          end


          obfuscated.to_s # return back to a regular String
        end

        QUOTED_STRINGS_REGEX = /'(?:[^']|'')*'|"(?:[^"]|"")*"/
        LABEL_LINE_REGEX     = /^([^:\n]*:\s+).*$/.freeze

        def obfuscate_postgres_explain(explain)
          explain.gsub!(QUOTED_STRINGS_REGEX) do |match|
            match.start_with?('"') ? match : '?'
          end
          explain.gsub!(LABEL_LINE_REGEX,   '\1?')
          explain
        end

        module ObfuscationHelpers
          # Note that the following two regexes are applied to a reversed version
          # of the query. This is why the backslash escape sequences (\' and \")
          # appear reversed within them.
          #
          # Note that some database adapters (notably, PostgreSQL with
          # standard_conforming_strings on and MySQL with NO_BACKSLASH_ESCAPES on)
          # do not apply special treatment to backslashes within quoted string
          # literals. We don't have an easy way of determining whether the
          # database connection from which a query was captured was operating in
          # one of these modes, but the obfuscation is done in such a way that it
          # should not matter.
          #
          # Reversing the query string before obfuscation allows us to get around
          # the fact that a \' appearing within a string may or may not terminate
          # the string, because we know that a string cannot *start* with a \'.
          REVERSE_SINGLE_QUOTES_REGEX = /'(?:''|'\\|[^'])*'/
          REVERSE_ANY_QUOTES_REGEX    = /'(?:''|'\\|[^'])*'|"(?:""|"\\|[^"])*"/

          NUMERICS_REGEX = /\b\d+\b/

          # We take a conservative, overly-aggressive approach to obfuscating
          # comments, and drop everything from the query after encountering any
          # character sequence that could be a comment initiator. We do this after
          # removal of string literals to avoid accidentally over-obfuscating when
          # a string literal contains a comment initiator.
          SQL_COMMENT_REGEX = Regexp.new('(?:/\*|--|#).*', Regexp::MULTILINE).freeze

          # We use these to check whether the query contains any quote characters
          # after obfuscation. If so, that's a good indication that the original
          # query was malformed, and so our obfuscation can't reliabily find
          # literals. In such a case, we'll replace the entire query with a
          # placeholder.
          LITERAL_SINGLE_QUOTE = "'".freeze
          LITERAL_DOUBLE_QUOTE = '"'.freeze

          PLACEHOLDER = '?'.freeze

          def obfuscate_single_quote_literals(sql)
            obfuscated = sql.reverse
            obfuscated.gsub!(REVERSE_SINGLE_QUOTES_REGEX, PLACEHOLDER)
            obfuscated.reverse!
            obfuscated
          end

          def obfuscate_quoted_literals(sql)
            obfuscated = sql.reverse
            obfuscated.gsub!(REVERSE_ANY_QUOTES_REGEX, PLACEHOLDER)
            obfuscated.reverse!
            obfuscated
          end

          def obfuscate_numeric_literals(sql)
            sql.gsub(NUMERICS_REGEX, PLACEHOLDER)
          end

          def remove_comments(sql)
            sql.gsub(SQL_COMMENT_REGEX, PLACEHOLDER)
          end

          def contains_single_quotes?(str)
            str.include?(LITERAL_SINGLE_QUOTE)
          end

          def contains_quotes?(str)
            str.include?(LITERAL_SINGLE_QUOTE) || str.include?(LITERAL_DOUBLE_QUOTE)
          end
        end
        include ObfuscationHelpers
      end

    end
  end
end
