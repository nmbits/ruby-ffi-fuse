# -*- coding: utf-8 -*-

require 'ffi/libfuse'
require 'fuseffi/filesystem'

module FuseFFI
  def self.main impl, fs_opt, *args
    case impl
    when FuseFFI::FileSystem
      fs_class = impl
    when Module
      fs_class = Class.new(FileSystem){ include impl }
    else
      raise TypeError, "specified object cannot be a file system implementation."
    end
    fs_class.new(fs_opt, *args).start
  end
end
