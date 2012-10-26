# -*- coding: utf-8 -*-

require 'ffi'
require 'rbconfig'

module FFI
  module Libfuse
    extend FFI::Library
    ffi_lib ['libfuse.so', 'libfuse.so.2']

    callback :fuse_fill_dir_t, [:pointer, :string, :pointer, :off_t], :int

    callback :fuse_getattr, [:string, :pointer], :int
    callback :fuse_readlink, [:string, :pointer, :size_t], :int
    callback :fuse_mknod, [:string, :mode_t, :dev_t], :int
    callback :fuse_mkdir, [:string, :mode_t], :int
    callback :fuse_unlink, [:string], :int
    callback :fuse_rmdir, [:string], :int
    callback :fuse_symlink, [:string, :string], :int
    callback :fuse_rename, [:string, :string], :int
    callback :fuse_link, [:string, :string], :int
    callback :fuse_chmod, [:string, :mode_t], :int
    callback :fuse_chown, [:string, :uid_t, :gid_t], :int
    callback :fuse_truncate, [:string, :off_t], :int
    callback :fuse_open, [:string, :pointer], :int
    callback :fuse_read, [:string, :pointer, :size_t, :off_t, :pointer], :int
    callback :fuse_write, [:string, :pointer, :size_t, :off_t, :pointer], :int
    callback :fuse_statfs, [:string, :pointer], :int
    callback :fuse_flush, [:string, :pointer], :int
    callback :fuse_release, [:string, :pointer], :int
    callback :fuse_fsync, [:string, :int, :pointer], :int
    callback :fuse_setxattr, [:string, :string, :pointer, :size_t, :int], :int
    callback :fuse_getxattr, [:string, :string, :pointer, :size_t], :int
    callback :fuse_listxattr, [:string, :pointer, :size_t], :int
    callback :fuse_removexattr, [:string, :string], :int
    callback :fuse_opendir, [:string, :pointer], :int
    callback :fuse_readdir, [:string, :pointer, :fuse_fill_dir_t, :off_t, :pointer], :int
    callback :fuse_releasedir, [:string, :pointer], :int
    callback :fuse_fsyncdir, [:string, :pointer], :int
    callback :fuse_init, [:pointer], :pointer
    callback :fuse_destroy, [:pointer], :void
    callback :fuse_access, [:string, :int], :int
    callback :fuse_create, [:string, :mode_t, :pointer], :int
    callback :fuse_ftruncate, [:string, :off_t, :pointer], :int
    callback :fuse_fgetattr, [:string, :pointer, :pointer], :int
    callback :fuse_lock, [:string, :pointer, :int, :pointer], :int
    callback :fuse_utimens, [:string, :pointer], :int
    callback :fuse_bmap, [:string, :size_t, :pointer], :int
    callback :fuse_ioctl, [:string, :int, :pointer, :pointer, :uint, :pointer], :int
    callback :fuse_poll, [:string, :pointer, :pointer, :pointer], :int

    class Operations < FFI::Struct
      layout(:getattr, :fuse_getattr,
             :readlink, :fuse_readlink,
             :getdir_deprecated, :pointer,
             :mknod, :fuse_mknod,
             :mkdir, :fuse_mkdir,
             :unlink, :fuse_unlink,
             :rmdir, :fuse_rmdir,
             :symlink, :fuse_symlink,
             :rename, :fuse_rename,
             :link, :fuse_link,
             :chmod, :fuse_chmod,
             :chown, :fuse_chown,
             :truncate, :fuse_truncate,
             :utime_deprecated, :pointer,
             :open, :fuse_open,
             :read, :fuse_read,
             :write, :fuse_write,
             :statfs, :fuse_statfs,
             :flush, :fuse_flush,
             :release, :fuse_release,
             :fsync, :fuse_fsync,
             :setxattr, :fuse_setxattr,
             :getxattr, :fuse_getxattr,
             :listxattr, :fuse_listxattr,
             :removexattr, :fuse_removexattr,
             :opendir, :fuse_opendir,
             :readdir, :fuse_readdir,
             :releasedir, :fuse_releasedir,
             :fsyncdir, :fuse_fsyncdir,
             :init, :fuse_init,
             :destroy, :fuse_destroy,
             :access, :fuse_access,
             :create, :fuse_create,
             :ftruncate, :fuse_ftruncate,
             :fgetattr, :fuse_fgetattr,
             :lock, :fuse_lock,
             :utimens, :fuse_utimens,
             :bmap, :fuse_bmap,
             :flags, :uint32,
             :ioctl, :fuse_ioctl,
             :poll, :fuse_poll)
      def initialize
        super
        @mark = {}
      end

      def set(sym, pr)
        self[sym] = @mark[sym] = pr
      end
    end

    class FileInfo < FFI::Struct
      layout(:flags, :int,
             :fh_old, :ulong,
             :writepage, :int,
             :bits, :uint32,
             # direct_io : 1
             # keep_cache : 1
             # flush : 1
             # nonseekable : 1
             # padding : 28
             :fh, :uint64,
             :lock_owner, :uint64)
    end

    class Context < FFI::Struct
      layout(:fuse, :pointer,
             :uid, :uid_t,
             :gid, :gid_t,
             :pid, :int32,
             :private_data, :pointer,
             :umask, :mode_t)
    end

    case RUBY_PLATFORM
    when /linux/
      machine = `uname -m`
      # From /usr/include/bits/stat.h
      case machine
      when 'x86_64'
        # for __WORDSIZE == 64
        class Stat < FFI::Struct
          layout(:st_dev, :__dev_t,
                 :st_ino, :__ino_t,
                 :st_nlink, :__nlink_t,
                 :st_mode, :__mode_t,
                 :st_uid, :__uid_t,
                 :st_gid, :__gid_t,
                 :__pad0, :int,
                 :st_rdev, :__dev_t,
                 :st_size, :__off_t,
                 :st_blksize, :__blksize_t,
                 :st_blocks, :__blkcnt_t,
                 :st_atime, :__time_t,
                 :st_atimensec, :ulong,
                 :st_mtime, :__time_t,
                 :st_mtimensec, :ulong,
                 :st_ctime, :__time_t,
                 :st_ctimensec, :ulong,
                 :__unused, [:long, 3]
                 )
        end
      else
        # for __WORDSIZE == 32. _FILE_OFFSET_BITS=64
        class Stat < FFI::Struct
          layout(:st_dev, :__dev_t,
                 :__pad1, :ushort,
                 :__st_ino, :__ino_t,
                 :st_mode, :__mode_t,
                 :st_nlink, :__nlink_t,
                 :st_uid, :__uid_t,
                 :st_gid, :__gid_t,
                 :st_rdev, :__dev_t,
                 :__pad2, :ushort,
                 :st_size, :__off64_t,
                 :st_blksize, :__blksize_t,
                 :st_blocks, :__blkcnt64_t,
                 :st_atime, :__time_t,
                 :st_atimensec, :ulong,
                 :st_mtime, :__time_t,
                 :st_mtimensec, :ulong,
                 :st_ctime, :__time_t,
                 :st_ctimensec, :ulong,
                 :st_ino, :__ino64_t
                 )
        end
      end
    end

    raise "unsupported platform" unless const_defined? :Stat

    class Timespec < FFI::Struct
      layout(:tv_sec, :__time_t,
             :tv_nsec, :ulong)
    end

    class CArg
      attr_reader :argc, :argv
      def initialize(*a)
        @argv = FFI::MemoryPointer.new :pointer, a.length + 1
        @mark = []
        a.each_with_index do |s, i|
          ptr = FFI::MemoryPointer.from_string(s)
          @argv.put_pointer i * FFI.type_size(:pointer), ptr
          @mark << ptr
        end
        @argc = a.length
        @argv.put_pointer @argc * FFI.type_size(:pointer), nil
      end
    end

    attach_function :fuse_version, [], :int

    # attach_function :fuse_mount, [:string, :pointer], :pointer
    # attach_function :fuse_unmount, [:string, :pointer], :void

    # attach_function :fuse_new, [:pointer, :pointer, :pointer,
    #                             :size_t, :pointer], :pointer
    # attach_function :fuse_destroy, [:pointer], :void
    # attach_function :fuse_loop, [:pointer], :int
    # attach_function :fuse_exit, [:pointer], :void

    # attach_function :fuse_get_context, [], :pointer
    # attach_function :fuse_get_session, [:pointer], :pointer

    # attach_function :fuse_opt_add_arg, [:pointer, :string], :int
    # attach_function :fuse_opt_free_args, [:pointer], :int

    # attach_function :fuse_session_exit, [:pointer], :void
    # attach_function :fuse_session_next_chan, [:pointer, :pointer], :pointer

    attach_function :fuse_main_real, [:int, :pointer, :pointer, :size_t,
                                      :pointer], :int
  end
end
