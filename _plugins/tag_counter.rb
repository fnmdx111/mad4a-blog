module Jekyll
  module TagCountFilter

    def tag_count(tag)
      @context.registers[:site].posts.map do |post|
        post.tags.include?(tag) ? 1 : 0
      end .inject {|x, acc| x + acc}
    end
  end
end

Liquid::Template.register_filter(Jekyll::TagCountFilter)

