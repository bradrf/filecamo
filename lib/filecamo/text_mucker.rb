require 'logger'
require 'filemagic'
require 'literate_randomizer'

# TODO: add option to change existing markers instead (or in addition to?) adding lines

module Filecamo
  class TextMucker
    MAX_FILE_SIZE = 128 * 1024

    LANG_MARKS = {
      csharp: '//',
      python: '#',
      ruby: '#',
      shell: '#',
      js: '#',
      plain: '#',
    }

    def initialize(comment_prefix, logger: Logger.new($stdout))
      @marks = LANG_MARKS.clone
      @marks.each_value{|m| m << comment_prefix}
      @logger = logger
      @magic = FileMagic.new
      @mime = FileMagic.mime
      @stats = {files_selected: 0, lines_added: 0}
    end

    attr_reader :stats

    def muck(percent_select, percent_lines, paths)
      select_chance = percent_select.to_f / 100
      lines_chance = percent_lines.to_f / 100

      paths.each do |path|
        path[0] == '.' and next
        if File.directory?(path)
          paths.concat(Dir.entries(path).map{|e| e[0] == '.' ? nil : File.join(path,e)}.compact)
          next
        end

        fn = path
        fn_size = File.size(fn)

        # todo: support working with large files by reading next line
        if fn_size > MAX_FILE_SIZE
          @logger.debug "Skipping #{fn} by size: #{file.size}"
          break
        end

        lang = case File.extname(fn)
               when '.cs' then :csharp
               when '.py' then :python
               when '.js' then :js
               when '.json' then :json
               when '.yaml','meta' then :yaml
               when '.html' then :html
               when '.txt' then :plain
               else
                 case m = @mime.file(fn)
                 when /python/ then :python
                 when /ruby/ then :ruby
                 when /shell/ then :shell
                 when /plain/
                   case g = @magic.file(fn)
                   when /python/ then :python
                   when /ruby/ then :ruby
                   when /node/ then :js
                   else
                     :plain
                   end
                 else
                   @logger.debug "Skipping #{fn} by mime type: #{m}"
                   next
                 end
               end

        if Random.rand > select_chance
          @logger.debug "Skipping #{fn} by chance"
          next
        end

        @stats[:files_selected] += 1

        new_lines = {}
        new_bytes_needed = (fn_size * lines_chance).floor
        while new_bytes_needed > 0
          offset = Random.rand(fn_size)
          new_line = get_line_for(lang)
          new_lines[offset] = new_line
          new_bytes_needed -= new_line.bytesize
        end
        new_lines = new_lines.sort
        @stats[:lines_added] += new_lines.size

        body = ''
        line_nums = []

        File.open(fn) do |file|
          line_num = 0
          while !file.eof? && line = file.readline
            body << line
            line_num += 1
            new_lines.empty? and next # read remainder of file
            offset = new_lines[0][0]
            if file.pos >= offset # add a line as soon as passed the offset
              offset, new_line = new_lines.shift
              line_nums << (line_num+=1)
              body << new_line
            end
          end

          # concat any remaining lines
          if !new_lines.empty?
            body[-1] == $/ or body << $/
            new_lines.each do |offset, new_line|
              line_num += 1
              line_nums << line_num
              body << new_line
            end
          end
        end

        # todo: use same charset as mime type indicates when writing!
        File.open(fn, 'wb') {|f| f.write(body)}

        block_given? and yield(fn, lang, line_nums)
      end
    end

    ######################################################################
    private

    def get_line_for(lang)
      mark = @marks[lang] or return ''
      # todo: match line endings of file!
      return mark + LiterateRandomizer.sentence + $/
    end
  end
end
