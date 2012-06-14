require 'chef/knife'

class Chef
  class Knife
    class DataBagEncrypt < Knife
      deps do
        require 'chef/data_bag'
        require 'chef/knife/core/object_loader'
        require 'chef/json_compat'
        require 'chef/encrypted_data_bag_item'
      end

      banner "knife data bag encrypt FILE (options)"
      category "data bag"

      option :secret,
      :short => "-s SECRET",
      :long  => "--secret ",
      :description => "The secret key to use to encrypt data bag item values"

      option :secret_file,
      :long => "--secret-file SECRET_FILE",
      :description => "A file containing the secret key to use to encrypt data bag item values"

      def read_secret
        if config[:secret]
          config[:secret]
        else
          Chef::EncryptedDataBagItem.load_secret(config[:secret_file])
        end
      end

      def use_encryption
        if config[:secret] && config[:secret_file] || (!config[:secret] && !config[:secret_file])
          ui.fatal("please specify only one of --secret, --secret-file")
          exit(1)
        end
        config[:secret] || config[:secret_file]
      end

      def loader
        @loader ||= Knife::Core::ObjectLoader.new(DataBagItem, ui)
      end

      def run
        if @name_args.size < 1
          ui.msg(opt_parser)
          exit(1)
        end
        load_data_bag_items(@name_args)
      end

      private
      def data_bags_path
        @data_bag_path ||= "data_bags"
      end

      def find_all_data_bags
        loader.find_all_object_dirs("./#{data_bags_path}")
      end

      def find_all_data_bag_items(data_bag)
        loader.find_all_objects("./#{data_bags_path}/#{data_bag}")
      end

      def load_all_data_bags(args)
        data_bags = args.empty? ? find_all_data_bags : [args.shift]
        data_bags.each do |data_bag|
          load_data_bag_items(data_bag)
        end
      end

      def load_data_bag_items(items)
        item_paths = normalize_item_paths(items)
        item_paths.each do |item_path|
          item = loader.load_from("#{data_bags_path}", item_path)
          secret = read_secret
          item = Chef::EncryptedDataBagItem.encrypt_data_bag_item(item, secret)
          output(format_for_display(item))
        end
      end

      def normalize_item_paths(args)
        paths = Array.new
        args.each do |path|
          if File.directory?(path)
            paths.concat(Dir.glob(File.join(path, "*.json")))
          else
            paths << path
          end
        end
        paths
      end
    end
  end
end
