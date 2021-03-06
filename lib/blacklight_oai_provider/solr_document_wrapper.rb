module BlacklightOaiProvider
  class SolrDocumentWrapper < ::OAI::Provider::Model
    attr_reader :model, :timestamp_field
    attr_accessor :options

    def initialize(controller, options = {})
      @controller = controller

      defaults = { :timestamp => 'timestamp', :limit => 15} 
      @options = defaults.merge options

      @timestamp_field = @options[:timestamp]
      @limit = @options[:limit]
    end

    def sets
    end

    def earliest
      records = @controller.get_search_results(@controller.params, {:fl => @timestamp_field, :sort => @timestamp_field +' asc', :rows => 1})
      raise OAI::NoMatchException.new if records[1].nil? or records[1].empty?
      Time.parse records.last.first.get(@timestamp_field)
    end

    def latest
      records = @controller.get_search_results(@controller.params, {:fl => @timestamp_field, :sort => @timestamp_field +' desc', :rows => 1})
      raise OAI::NoMatchException.new if records[1].nil? or records[1].empty?
      Time.parse records.last.first.get(@timestamp_field)
    end

    def find(selector, options={})
      return next_set(options[:resumption_token]) if options[:resumption_token]

      if :all == selector
        response, records = @controller.get_search_results(@controller.params, {:sort => @timestamp_field + ' asc', :rows => @limit})

        if @limit && response.total >= @limit
          return select_partial(OAI::Provider::ResumptionToken.new(options.merge({:last => 0})))
        end
      else                                                    
        records = @controller.get_search_results(@controller.params, {:phrase_filters => {:id => selector.split('/', 2).last}}).last.first
      end
      records
    end

    def select_partial token
      records = @controller.get_search_results(@controller.params, {:sort => @timestamp_field + ' asc', :rows => @limit, :start => token.last}).last

      raise ::OAI::ResumptionTokenException.new unless records


      next_token = token.next(token.last+@limit)

      #if the results are lower than the page display limit, then were are at the end of our results and sould send an empty resumption token
      if(records.size < @limit)
       next_token = OAI::Provider::ResumptionToken.new(options.merge({:last => ''}))       
      end

      OAI::Provider::PartialResult.new(records, next_token)
    end

    def next_set(token_string)
      raise ::OAI::ResumptionTokenException.new unless @limit

      token = OAI::Provider::ResumptionToken.parse(token_string)
      select_partial(token)
    end
  end
end

