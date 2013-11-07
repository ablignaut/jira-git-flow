module Jira
  class CLI < Thor

    desc "describe", "Describes the input ticket"
    def describe(ticket=Jira::Core.ticket)
      puts description(ticket.strip)
    end

    desc "all", "Describes all local branches that match JIRA ticketing syntax"
    def all
      # determine which local branches match JIRA ticket syntax
      #   TODO - move to Jira::Git
      tickets = {
        current: nil,
        others: []
      }
      branches = `git branch`.strip.split("\n")
      branches.each do |branch|
        ticket = branch.delete('*').strip
        if Jira::Core.ticket?(ticket)
          if branch.include?('*')
            tickets[:current] = ticket
          else
            tickets[:others] << ticket
          end
        end
      end


      # asynchronously fetch and describe tickets
      output = ""
      threads = []
      threads << Thread.new{ puts description(tickets[:current], true) }
      mutex = Mutex.new
      tickets[:others].each do |ticket|
        threads << Thread.new do
          out = description(ticket) + "\n"
          mutex.synchronize{ output << out }
        end
      end
      threads.each{ |thread| thread.join }

      puts output
    end

    protected

      #
      # Returns a formatted description of the input ticket
      #
      # @param ticket [String] the ticket to describe
      # @param star [Boolean] if true, adds a * indicator
      #
      # @return [String] formatted summary string
      #
      def description(ticket, star=false)
        json = @api.get("issue/#{ticket}")
        summary = json['fields']['summary']
        status = json['fields']['status']['name']
        return Jira::Format.ticket(ticket) +
               (star ? Jira::Format.star : " ") +
               Jira::Format.status(status) +
               Jira::Format.summary(summary)
      end

  end
end
