
module HelloWorld
  S_IFREG = 0100000
  S_IFDIR = 0040000
  MESSAGE = "Hello, World."
  def getattr(path)
    stat = {}
    case path
    when "/"
      return {:mode => S_IFDIR | 0755, :nlink => 2 }
    when "/hello"
      t = Time.now.to_i
      return {
        :mode => S_IFREG | 0444,
        :nlink => 1,
        :size => MESSAGE.length,
        :uid => 1000,
        :gid => 1000,
        :atime => t,
        :mtime => t,
        :ctime => t
      }
    else
      raise Errno::ENOENT
    end
    return stat
  end

  def readdir(path, fh)
    [".", "..", "hello"]
  end

  def opendir(path)
  end

  def open(path, flags)
    raise Errno::ENOENT if path != "/hello"
    raise Errno::EACCESS unless flags & 3 == File::Constants::RDONLY
    nil
  end

  def read(path, size, offset, fh)
    MESSAGE[offset, size] # BAD IDEA
  end

  def init(*a)
    p "here"
  end
end

if __FILE__ == $0
  begin
    require 'fuseffi'
  rescue LoadError
    $: << '../lib'
    require 'fuseffi'
  end
  FuseFFI.main HelloWorld, nil, "hello"
end
