module TruncateHtml
  class HtmlTruncator
    
    attr_reader :offset, :_offset_count, :_tokens
    
    def initialize(original_html, options = {})
      @original_html   = original_html
      @_tokens         = @original_html.html_tokens
      @offset          = options[:offset]       
      @_offset_count   = 0
      length           = @offset ? options[:length] : options[:length] || TruncateHtml.configuration.length
      @omission        = options[:omission]     || TruncateHtml.configuration.omission
      @word_boundary   = (options.has_key?(:word_boundary) ? options[:word_boundary] : TruncateHtml.configuration.word_boundary)
      @break_token     = options[:break_token] || TruncateHtml.configuration.break_token || nil
      @chars_remaining = length ? length - @omission.length : @original_html.length 
      @open_tags, @truncated_html = [], []
    end

    def truncate
      return @omission if @chars_remaining < 0
      
      _tokens.each do |token|
        if @chars_remaining <= 0 || truncate_token?(token)
          close_open_tags
          break
        else
          process_token(token)
        end
      end
      prepend_omission if @offset && @offset > 0
      out = @truncated_html.join
      
      if word_boundary
        term_regexp = Regexp.new("^.*#{word_boundary.source}")
        match = out.match(term_regexp)
        match ? match[0] : out
      else
        out
      end
    end

    private
    
    def process_offset_token(token)
      if token.html_tag?
        if token.open_tag?
          @open_tags << token
        else
          remove_latest_open_tag(token, @open_tags)
        end
      end
    end
    
    def word_boundary
      if @word_boundary == true
        TruncateHtml.configuration.word_boundary
      else
        @word_boundary
      end
    end
    
    def prepend_omission
      first_non_html_token = @truncated_html.detect {|token| !HtmlString.new(token).html_tag?}
      idx = @truncated_html.index(first_non_html_token)
      @truncated_html.insert(idx, @omission)
    end
    
    def process_token(token)
      append_to_result(token)
      if token.html_tag?
        if token.open_tag?
          @open_tags << token
        else
          remove_latest_open_tag(token, @open_tags)
        end
      elsif !token.html_comment? && offset?
        @chars_remaining -= (@word_boundary ? token.length : token[0, @chars_remaining].length)
        if @chars_remaining <= 0
          @truncated_html[-1] = @truncated_html[-1].rstrip + @omission
        end
      end
    end

    def append_to_result(token)
      if token.html_tag? || token.html_comment?
        @truncated_html << token
      elsif @word_boundary
        if !offset? 
          @_offset_count += token.length
        else
          @truncated_html << token if (@chars_remaining - token.length) >= 0
        end
      else
        if !offset? 
          @_offset_count += token.length
        else
          @truncated_html << token[0, @chars_remaining]
        end
      end
    end
    
    def offset?
      !offset || _offset_count >= offset
    end

    def close_open_tags
      @open_tags.reverse_each do |open_tag|
        @truncated_html << open_tag.matching_close_tag
      end
    end

    def remove_latest_open_tag(close_tag, from_array)
      (0...from_array.length).to_a.reverse.each do |index|
        if from_array[index].matching_close_tag == close_tag
          from_array.delete_at(index)
          break
        end
      end
    end

    def truncate_token?(token)
      @break_token and token == @break_token
    end
  end
end
