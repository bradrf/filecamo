require 'logger'
require 'thread'
require 'thwait'
require 'pathname'
require 'better_bytes'
require 'literate_randomizer'

module Filecamo
  class Generator
    def initialize(logger: Logger.new($stdout),
                   txt_workers: {count: 4, queue_size: 5000},
                   bin_workers: {count: 4, queue_size: 5000})
      @gen = Random.new
      @logger = logger
      @words_generated = {}
      @stats = {txt: 0, bin: 0}

      @txt_work_q = SizedQueue.new(txt_workers[:queue_size])
      @txt_workers = start_workers(:txt, @txt_work_q, txt_workers[:count]) do |file, len|
        while len > 0
          line = (LiterateRandomizer.sentence + $/)
          line.slice!(len..-1)
          len -= file.write(line)
        end
        @stats[:txt] += 1
      end

      @bin_work_q = SizedQueue.new(bin_workers[:queue_size])
      @bin_workers = start_workers(:bin, @bin_work_q, bin_workers[:count]) do |file, len|
        while len > 0
          len -= file.write(@gen.bytes(len < 32768 ? len : 32768))
        end
        @stats[:bin] += 1
      end
    end

    attr_reader :stats

    def generate(min, max, count, depth, percent_text: 0, destination_path: nil, &block)
      min = BetterBytes.dehumanize(min)
      max = BetterBytes.dehumanize(max)
      count = count.to_i
      depth = depth.to_i
      percent_text = percent_text.to_f / 100
      dst_pn = Pathname.new(destination_path || '.')
      feed_workers(min, max, count, depth, percent_text, dst_pn, &block)
    end

    def wait(sleep_interval: 0.3)
      until @txt_work_q.empty? && @bin_work_q.empty?
        block_given? and
          yield(@txt_work_q.size, @bin_work_q.size)
        sleep(sleep_interval)
      end
    end

    def kill
      (@txt_workers + @bin_workers).each{|th| th.kill}
      ThreadsWait.all_waits(@txt_workers + @bin_workers) do |th|
        th.join
      end
    end

    ######################################################################
    private

    def start_workers(name, queue, count)
      count.times.map do
        Thread.new do
          begin
            loop do
              len, fn = queue.pop
              fn.open('wb') do |file|
                yield file, len
              end
            end
          rescue Exception => ex
            @logger.fatal "#{Thread.current} failed (#{name})"
            @logger.fatal ex
          end
        end
      end
    end

    def feed_workers(min, max, count, depth, percent_text, dst_pn)
      paths = {}

      count.times do |i|
        d = Random.rand(depth)
        if d < 1
          pn = Pathname.new('')
        else
          pn = nil
          pns = paths[d] and pn = pns[@gen.rand(pns.size)]
          unless pn
            pn = Pathname.new(gen_name)
            d.times{ pn += gen_name }
            (paths[d] ||= []) << pn
          end
        end

        fn = dst_pn + pn + (gen_name + (@gen.rand > percent_text ? '.bin' : '.txt'))
        fn.parent.mkpath
        len = @gen.rand(min..max).round

        block_given? and
          yield(fn, len)

        if fn.extname == '.txt'
          @txt_work_q.push([len, fn])
        else
          @bin_work_q.push([len, fn])
        end
      end
    end

    def gen_name
      # guarantee the same capitalization is used for the same word
      word = LiterateRandomizer.word
      lword = word.downcase
      prev_word = @words_generated[lword] and
        return prev_word
      return @words_generated[lword] = word
    end
  end
end
