#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Daniel DeLeo (<dan@opscode.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2008-2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/log'

class Chef
  class FileAccessControl
    module Unix
      UINT = (1 << 32)
      UID_MAX = (1 << 32) - 10

      def set_all
        set_owner
        set_group
        set_mode
      end

      # Workaround the fact that Ruby's Etc module doesn't believe in negative
      # uids, so negative uids show up as the diminished radix complement of
      # a uint. For example, a uid of -2 is reported as 4294967294
      def diminished_radix_complement(int)
        if int > UID_MAX
          int - UINT
        else
          int
        end
      end

      def target_uid
        return nil if resource.owner.nil?
        if resource.owner.kind_of?(String)
          diminished_radix_complement( Etc.getpwnam(resource.owner).uid )
        elsif resource.owner.kind_of?(Integer)
          resource.owner
        else
          Chef::Log.error("The `owner` parameter of the #@resource resource is set to an invalid value (#{resource.owner.inspect})")
          raise ArgumentError, "cannot resolve #{resource.owner.inspect} to uid, owner must be a string or integer"
        end
      rescue ArgumentError
        raise Chef::Exceptions::UserIDNotFound, "cannot determine user id for '#{resource.owner}', does the user exist on this system?"
      end

      def set_owner
        if (uid = target_uid) && (uid != stat.uid)
          chown(uid, nil, file)
          Chef::Log.info("#{log_string} owner changed to #{uid}")
          modified
        end
      end

      def target_gid
        return nil if resource.group.nil?
        if resource.group.kind_of?(String)
          diminished_radix_complement( Etc.getgrnam(resource.group).gid )
        elsif resource.group.kind_of?(Integer)
          resource.group
        else
          Chef::Log.error("The `group` parameter of the #@resource resource is set to an invalid value (#{resource.owner.inspect})")
          raise ArgumentError, "cannot resolve #{resource.group.inspect} to gid, group must be a string or integer"
        end
      rescue ArgumentError
        raise Chef::Exceptions::GroupIDNotFound, "cannot determine group id for '#{resource.group}', does the group exist on this system?"
      end

      def set_group
        if (gid = target_gid) && (gid != stat.gid)
          chown(nil, gid, file)
          Chef::Log.info("#{log_string} group changed to #{gid}")
          modified
        end
      end

      def target_mode
        return nil if resource.mode.nil?
        (resource.mode.respond_to?(:oct) ? resource.mode.oct : resource.mode.to_i) & 007777
      end

      def set_mode
        if (mode = target_mode) && (mode != (stat.mode & 007777))
          chmod(target_mode, file)
          Chef::Log.info("#{log_string} mode changed to #{mode.to_s(8)}")
          modified
        end
      end

      def stat
        if File.symlink?(file)
          @stat ||= File.lstat(file)
        else
          @stat ||= File.stat(file)
        end
      end

      private

      def chmod(mode, file)
        if File.symlink?(file)
          begin
            File.lchmod(mode, file)
          rescue NotImplementedError
            Chef::Log.warn("#{file} mode not changed: File.lchmod is unimplemented on this OS and Ruby version")
          end
        else
          File.chmod(mode, file)
        end
      end

      def chown(uid, gid, file)
        if ::File.symlink?(file)
          File.lchown(uid, gid, file)
        else
          File.chown(uid, gid, file)
        end
      end
    end
  end
end
