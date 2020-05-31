# frozen_string_literal: true

module RuboCop
  module Cop
    # This module contains a collection of useful utility methods.
    module Util
      include PathUtil

      # Match literal regex characters, not including anchors, character
      # classes, alternatives, groups, repetitions, references, etc
      LITERAL_REGEX =
        %r{[\w\s\-,"'!#%&<>=;:`~/]|\\[^AbBdDgGhHkpPRwWXsSzZ0-9]}.freeze

      module_function

      def comment_line?(line_source)
        line_source.match?(/^\s*?#/)
      end

      def comment_lines?(node)
        processed_source[line_range(node)].any? { |line| comment_line?(line) }
      end

      def line_range(node)
        node.first_line..node.last_line
      end

      def parentheses?(node)
        node.loc.respond_to?(:end) && node.loc.end &&
          node.loc.end.is?(')')
      end

      def add_parentheses(node, corrector)
        if node.arguments.empty?
          corrector.insert_after(node, '()')
        else
          corrector.replace(args_begin(node), '(')
          corrector.insert_after(args_end(node), ')')
        end
      end

      def args_begin(node)
        loc = node.loc
        selector =
          node.super_type? || node.yield_type? ? loc.keyword : loc.selector
        selector.end.resize(1)
      end

      def args_end(node)
        node.loc.expression.end
      end

      def on_node(syms, sexp, excludes = [], &block)
        return to_enum(:on_node, syms, sexp, excludes) unless block_given?

        yield sexp if Array(syms).include?(sexp.type)
        return if Array(excludes).include?(sexp.type)

        sexp.each_child_node { |elem| on_node(syms, elem, excludes, &block) }
      end

      def begins_its_line?(range)
        (range.source_line =~ /\S/) == range.column
      end

      # Returns, for example, a bare `if` node if the given node is an `if`
      # with calls chained to the end of it.
      def first_part_of_call_chain(node)
        while node
          case node.type
          when :send
            node = node.receiver
          when :block
            node = node.send_node
          else
            break
          end
        end
        node
      end

      # If converting a string to Ruby string literal source code, must
      # double quotes be used?
      def double_quotes_required?(string)
        # Double quotes are required for strings which either:
        # - Contain single quotes
        # - Contain non-printable characters, which must use an escape

        # Regex matches IF there is a ' or there is a \\ in the string that is
        # not preceded/followed by another \\ (e.g. "\\x34") but not "\\\\".
        string =~ /'|(?<! \\) \\{2}* \\ (?![\\"])/x
      end

      def needs_escaping?(string)
        double_quotes_required?(escape_string(string))
      end

      def escape_string(string)
        string.inspect[1..-2].tap { |s| s.gsub!(/\\"/, '"') }
      end

      def to_string_literal(string)
        if needs_escaping?(string) && compatible_external_encoding_for?(string)
          string.inspect
        else
          "'#{string.gsub('\\') { '\\\\' }}'"
        end
      end

      def trim_string_interporation_escape_character(str)
        str.gsub(/\\\#{(.*?)\}/) { "\#{#{Regexp.last_match(1)}}" }
      end

      def interpret_string_escapes(string)
        StringInterpreter.interpret(string)
      end

      def same_line?(node1, node2)
        node1.respond_to?(:loc) &&
          node2.respond_to?(:loc) &&
          node1.loc.line == node2.loc.line
      end

      def to_supported_styles(enforced_style)
        enforced_style
          .sub(/^Enforced/, 'Supported')
          .sub('Style', 'Styles')
      end

      def tokens(node)
        @tokens ||= {}
        return @tokens[node.object_id] if @tokens[node.object_id]

        source_range = node.source_range
        begin_pos = source_range.begin_pos
        end_pos = source_range.end_pos

        #binding.pry

        #left = index_of_first_token(node)
        #right = index_of_last_token(node)
        #@tokens[node.object_id] = processed_source.tokens[left..right]

         @tokens[node.object_id] = processed_source.tokens.select do |token|
           token.end_pos <= end_pos && token.begin_pos >= begin_pos
         end
      end

      private

      def compatible_external_encoding_for?(src)
        src = src.dup if RUBY_ENGINE == 'jruby'
        src.force_encoding(Encoding.default_external).valid_encoding?
      end
    end
  end
end
