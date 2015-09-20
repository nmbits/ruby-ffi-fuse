
require 'ffi/libfuse'

module FuseFFI
  class FileSystem
    S_IFDIR = 0040000
    S_IFCHR = 0020000
    S_IFBLK = 0060000
    S_IFREG = 0100000
    S_IFIFO = 0010000
    S_IFLNK = 0120000
    S_IFSOCK = 0140000

    def self.new(fs_opt, *args)
      allocate.instance_eval do
        initialize fs_opt
        a = args.dup
        a.unshift "-s" # force single thread
        a.unshift "-f" # force foreground
        a.unshift ::File.basename($0) # default subtype
        @_fuse_carg = FFI::Libfuse::CArg.new *a
        @_fuse_ops = FFI::Libfuse::Operations.new
        [:getattr,   :readlink, :mknod,      :mkdir,
         :unlink,    :rmdir,    :symlink,    :rename,
         :link,      :chmod,    :chown,      :truncate,
         :open,      :read,     :write,      :statfs,
         :flush,     :release,  :fsync,
         :setxattr,  :getxattr, :listxattr,  :removexattr,
         :opendir,   :readdir,  :releasedir, :fsyncdir,
         :_x_init,   :destroy,  :access,     :create,
         :ftruncate, :fgetattr, :lock,       :utimens,
         :bmap,      :ioctl,    :poll
        ].each do |sym|
          next unless respond_to?(sym, true) || sym == :release || sym == :releasedir
          instance_eval %{
            def self._fuse_#{sym}_cb(*a)
              _fuse_invoke :_fuse_#{sym}, a
            end
          }
          @_fuse_ops.set sym, method("_fuse_#{sym}_cb")
        end
        @_fuse_file_handles = {}
        self
      end
    end

    def initialize(opt)
    end

    def start
      FFI::Libfuse.fuse_main_real(@_fuse_carg.argc, @_fuse_carg.argv,
                                  @_fuse_ops, @_fuse_ops.size, nil)
    end

    private

    def _fuse_invoke(sym, args)
      return self.__send__ sym, *args
    rescue SystemCallError
      return (0 - $!.class::Errno)
    rescue Exception
      p $!
      p $!.backtrace
      return (0 - Errno::ENOSYS::Errno)
    end

    def _fuse_getattr(path, stat_ptr)
      stat = getattr path
      fuse_stat = FFI::Libfuse::Stat.new stat_ptr      
      case stat
      when File::Stat
        [:dev, :ino, :mode, :nlink,
         :uid, :gid, :rdev, :size,
         :blksize, :blocks].each do |s|
          fuse_stat["st_#{s}".to_sym] = stat.__send__ s
        end
        [:atime, :mtime, :ctime].each do |s|
          fuse_stat["st_#{s}".to_sym] = stat.__send__(s).to_i
        end
      when Hash
        [:dev, :ino, :mode, :nlink,
         :uid, :gid, :rdev, :size,
         :blksize, :blocks,
         :atime, :mtime, :ctime,
         :atimensec, :mtimensec, :ctimensec].each do |s|
          fuse_stat["st_#{s}".to_sym] = stat[s].to_i if stat.include? s
        end
      else
        raise TypeError
      end
      return 0
    end

    def _fuse_readlink(path, char_ptr, size)
      r = readlink path
      raise Errno::E2BIG if r.length + 1 > size # ?
      char_ptr.put_string 0, r
      return 0
    end

    def _fuse_mknod(path, mode, dev)
      mknod path, mode, dev
      return 0
    end

    def _fuse_mkdir(path, mode)
      mkdir path, mode
      return 0
    end

    def _fuse_unlink(path)
      unlink path
      return 0
    end

    def _fuse_rmdir(path)
      rmdir path
      return 0
    end

    def _fuse_symlink(path1, path2)
      symlink path1, path2
      return 0
    end

    def _fuse_rename(path1, path2)
      rename path1, path2
      return 0
    end

    def _fuse_link(path1, path2)
      link path1, path2
      return 0
    end

    def _fuse_chmod(path, mode)
      chmod path, mode
      return 0
    end

    def _fuse_chown(path, uid, gid)
      chown path, uid, gid
      return 0
    end

    def _fuse_truncate(path, off)
      truncate path, off
      return 0
    end

    def _fuse_inc_file_handle(fh)
      ent = (@_fuse_file_handles[fh.__id__] ||= [0, fh])
      ent[0] += 1
      return fh.__id__
    end

    def _fuse_dec_file_handle(fh)
      ent = @_fuse_file_handles[fh.__id__]
      if ent
        ent[0] -= 1
        @_fuse_file_handles.delete fh.__id__ if ent[0] <= 0
      end
      nil
    end

    def _fuse_get_file_handle(fi_ptr)
      fi = FFI::Libfuse::FileInfo.new fi_ptr
      ent = @_fuse_file_handles[fi[:fh]]
      return (ent ? ent[1] : nil)
    end

    def _fuse_open(path, fi_ptr)
      fi = FFI::Libfuse::FileInfo.new fi_ptr
      flags = fi[:flags]
      fh = open path, flags
      if fh
        fi[:fh] = _fuse_inc_file_handle fh
      else
        fi[:fh] = 0
      end
      return 0
    end

    def _fuse_read(path, buf, size, off, fi_ptr)
      fh = _fuse_get_file_handle(fi_ptr)
      data = read path, size, off, fh
      ret_size = (size < data.length ? size : data.length)
      buf.write_string_length data, ret_size
      return ret_size
    end

    def _fuse_write(path, buf, size, off, fi_ptr)
      fh = _fuse_get_file_handle(fi_ptr)
      str = buf.read_string_length size
      return write(path, str, off, fh)
    end

    def _fuse_statfs(*a) #TODO
      return 0
    end

    def _fuse_flush(path, fi_ptr) #TODO
      flush path
      return 0
    end

    def _fuse_release(path, fi_ptr)
      fh = _fuse_get_file_handle fi_ptr
      release path, fh if respond_to? :release, true
      _fuse_dec_file_handle fh if fh
      return 0
    end

    def _fuse_fsync(path, sync, fi_ptr)
      fh = _fuse_get_file_handle fi_ptr
      fsync path, (sync != 0 ? true : false), fh
      return 0
    end

    def _fuse_setxattr(path, attr, value, sz, flag) #todo
      return 0
    end

    def _fuse_getxattr(path, attr, value, sz) #TODO
      return 0
    end

    def _fuse_listxattr(path, attr, sz) #TODO
      return 0
    end

    def _fuse_removexattr(path, attr) #TODO
      return 0
    end

    def _fuse_opendir(path, fi_ptr) #TODO
      fi = FFI::Libfuse::FileInfo.new fi_ptr
      fh = opendir path
      if fh
        fi[:fh] = _fuse_inc_file_handle fh
      else
        fi[:fh] = 0
      end
      return 0
    end

    def _fuse_readdir(path, buf_ptr, filler, offset, fi_ptr)
      fh = _fuse_get_file_handle fi_ptr
      ret = readdir path, fh
      ret.each do |r|
        filler.call buf_ptr, r.to_s, nil, 0
      end
      return 0
    end

    def _fuse_releasedir(path, fi_ptr) #TODO
      fh = _fuse_get_file_handle fi_ptr
      releasedir path, fh if respond_to?(:releasedir, true)
      _fuse_dec_file_handle fh if fh
      return 0
    end

    def _fuse_fsyncdir(path, fi_ptr) #TODO
      return 0
    end

    def _fuse_access(path, data) #TODO
      return 0
    end

    def _fuse_create(path, mode, fi_ptr)
      fi = FFI::Libfuse::FileInfo.new fi_ptr
      flags = fi[:flags]
      fh = create path, mode, flags
      if fh
        fi[:fh] = _fuse_inc_file_handle fh
      else
        fi[:fh] = 0
      end
      return 0
    end

    def _fuse_ftruncate(path, off, fi_ptr)
      fh = _fuse_get_file_handle fi_ptr
      ftruncate path, off, fh
      return 0
    end

    def _fuse_utimens(path, ts_ptr)
      atimespec = FFI::Libfuse::Timespec.new ts_ptr
      mtimespec = FFI::Libfuse::Timespec.new(ts_ptr + FFI::Libfuse::Timespec.size)
      utimens(path,
              atimespec[:tv_sec], atimespec[:tv_nsec],
              mtimespec[:tv_sec], mtimespec[:tv_nsec])
      return 0
    end

    def _fuse_poll(path, fi_ptr, ph_ptr, rv_ptr) #TODO
      return 0
    end
  end
end
