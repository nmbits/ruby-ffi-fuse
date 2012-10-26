#!/usr/bin/ruby1.9.1

require 'stringio'
require 'pp'

module HashIO
  class INode
    S_IFDIR = 0040000
    S_IFCHR = 0020000
    S_IFBLK = 0060000
    S_IFREG = 0100000
    S_IFIFO = 0010000
    S_IFLNK = 0120000
    S_IFSOCK = 0140000

    def initialize(mode)
      @time = Time.now
      @nlink = 0
      @mode = mode
    end

    def getattr
      {
        :mtime => @time.to_i,
        :ctime => @time.to_i,
        :atime => @time.to_i,
        :nlink => @nlink,
        :uid => Process.uid,
        :gid => Process.gid,
        :mode => @mode,
        :size => size
      }
    end

    def size
      0
    end

    def inc
      @nlink += 1
    end

    def dec
      @nlink -= 1
    end
  end

  class Directory < INode
    def initialize(mode)
      super(S_IFDIR | mode)
      @entries = { "." => self }
      inc
    end

    def list
      @entries.keys
    end

    def [](name)
      @entries[name]
    end

    def include?(name)
      @entries.include? name
    end

    def add(name, inode)
      raise Errno::EEXIST if @entries.include? name
      if Directory === inode
        raise Errno::EISDIR if inode.include? ".."
        inode.set_parent self
      end
      @entries[name] = inode
      inode.inc
    end

    def delete(name)
      inode = @entries[name]
      if inode
        @entries.delete name
        inode.dec
        inode.unset_parent if Directory === inode
      end
    end

    def set_parent(dir)
      @entries[".."] = dir
      dir.inc
    end

    def unset_parent
      dir = @entries[".."]
      @entries.delete ".."
      dir.dec
    end
  end

  class File < INode
    def initialize(mode)
      super(S_IFREG | mode)
      @io = StringIO.new
    end

    def write(str, pos)
      @io.pos = pos
      @io.write str
      str.length
    end

    def read(len, pos)
      @io.pos = pos
      @io.read(len) || ""
    end

    def truncate(size)
      @io.truncate size
    end

    def size
      @io.size
    end
  end

  def initialize(*a)
    @root = Directory.new(0644)
  end

  def lookup(path)
    names = path.split '/'
    names.shift
    current = @root
    inodes = [@root]
    flag = :found
    last_name = nil
    names.each do |name|
      inode = current[name]
      last_name = name
      case inode
      when Directory
        inodes << inode
        current = inode
      when File
        if name.equal? names.last
          inodes << inode
        else
          flag = :not_found
        end
        break
      else
        flag = (name.equal?(names.last) ? :parent_exist : :not_found)
        break
      end
    end
    return flag, inodes, last_name
  end

  def open(path, flag)
    f, inodes = lookup(path)
    raise Errno::ENOENT unless f == :found
    raise Errno::EISDIR if Directory === inodes.last
    nil
  end

  def readdir(path, fh)
    f, inodes = lookup path
    raise Errno::ENOENT unless f == :found
    raise Errno::ENOTDIR unless Directory === inodes.last
    inodes.last.list
  end

  def rmdir(path)
    f, inodes, name = lookup path
    raise Errno::ENOENT unless f == :found
    parent = inodes[-2]
    parent.delete name
  end
  alias_method :unlink, :rmdir

  def mkdir(path, mode)
    f, inodes, name = lookup path
    case f
    when :not_found
      raise Errno::ENOENT
    when :found
      raise Errno::EEXIST
    end
    inodes.last.add name, Directory.new(mode)
  end

  def getattr(path)
    f, inodes = lookup path
    raise Errno::ENOENT unless f == :found
    inodes.last.getattr
  end

  def read(path, off, len, fh)
    f, inodes = lookup path
    raise Errno::ENOENT unless f == :found
    inode = inodes.last
    raise Errno::EINVAL unless File === inode # correct?
    inode.read off, len
  end

  def write(path, buf, off, fh)
    f, inodes = lookup path
    raise Errno::ENOENT unless f == :found
    inode = inodes.last
    raise Errno::EINVAL unless File === inode # correct ?
    inode.write buf, off
    buf.size
  end

  def create(path, mode, flags)
    f, inodes, name = lookup path
    case f
    when :found
      raise Errno::EEXIST
    when :not_found
      raise Errno::ENOENT
    end
    parent = inodes.last
    parent.add name, File.new(mode)
    nil
  end

  def truncate(path, size)
    f, inodes = lookup path
    raise Errno::ENOENT unless f == :found
    inode = inodes.last
    raise Errno::EINVAL unless File === inode # correct ?
    inode.truncate size
  end

  def rename(spath, dpath)
    f, slist, sname = lookup spath
    raise Errno::ENOENT unless f == :found
    f, dlist, dname = lookup dpath
    case f
    when :not_found
      raise Errno::ENOENT
    when :found
      raise Errno::EEXIST
    when :parent_exist
      dparent = dlist.last
    end
    inode = slist.last
    sparent = slist[-2]
    sparent.delete sname
    dparent.add dname, inode
  end

  def utimens(path, *a)
    # TODO
  end
end

if __FILE__ == $0
  begin
    require 'fuseffi'
  rescue LoadError
    $: << '../lib'
    require 'fuseffi'
  end
  FuseFFI.main HashIO, nil, *ARGV
end
