# encoding: utf-8

module TingYun
  module Agent
    module Database

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
