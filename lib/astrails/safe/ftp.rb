module Astrails
  module Safe
    class Ftp < Sink

      protected

      def active?
        host && user
      end

      def path
        @path ||= expand(config[:ftp, :path] || config[:local, :path] || ":kind/:id")
      end

      def save
        raise RuntimeError, "pipe-streaming not supported for FTP." unless @backup.path

        puts "Uploading #{host}:#{full_path} via FTP" if $_VERBOSE || $DRY_RUN

        unless $DRY_RUN || $LOCAL
          Net::FTP.open(host, user, password) do |ftp|
            ftp.passive = passive?
            puts "Sending #{@backup.path} to #{full_path}" if $_VERBOSE
            begin
              ftp.putbinaryfile @backup.path, full_path
            rescue Net::FTPPermError
              puts "Ensuring remote path (#{path}) exists" if $_VERBOSE
              # mkdir -p
              folders = path.split('/')
              folders.each_index do |i|
                folder = folders[0..i].join('/')
                puts "Creating #{folder} on remote" if $_VERBOSE
                ftp.mkdir(folder) rescue Net::FTPPermError
              end
              retry
            end
          end
          puts "...done" if $_VERBOSE
        end
      end

      def cleanup
        return if $LOCAL || $DRY_RUN

        return unless keep = @config[:keep, :ftp]

        puts "listing files: #{host}:#{base}*" if $_VERBOSE
        Net::FTP.open(host, user, password) do |ftp|
          puts passive?.inspect
          ftp.passive = passive?
          ftp.chdir(path)
          
          files = ftp.nlst(File.basename("#{base}*")).sort

          puts files.join(", ") if $_VERBOSE

          cleanup_with_limit(files, keep) do |file|
            puts "removing ftp file #{host}:#{file}" if $DRY_RUN || $_VERBOSE
            ftp.delete(file) unless $DRY_RUN || $LOCAL
          end
        end
      end

      def host
        @config[:ftp, :host]
      end

      def user
        @config[:ftp, :user]
      end

      def password
        @config[:ftp, :password]
      end

      def passive?
        @config[:ftp, :passive]
      end
      
    end
  end
end