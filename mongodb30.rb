require "language/go"

class Mongodb30 < Formula
  desc ""
  homepage "https://github.com/nownabe/homebrew-mongodb30"

  url "https://fastdl.mongodb.org/src/mongodb-src-r3.0.7.tar.gz"
  version "3.0.7"
  sha256 "2d25bae7c3bfb3c0e168fcad526dc212da72faaeae6d1573db631cacb172a7e7"

  go_resource "github.com/mongodb/mongo-tools" do
    url "https://github.com/mongodb/mongo-tools.git",
      tag: "r3.0.7", revision: "134c548992e8248c7a7c53777a652cbb2490ab6c"
  end

  needs :cxx11

  depends_on "go" => :build
  depends_on "scons" => :build
  depends_on "openssl" => :optional

  def install
    ENV.cxx11 if MacOS.version < :mavericks
    ENV.libcxx if build.devel?

    Language::Go.stage_deps resources, buildpath/"src"

    cd "src/github.com/mongodb/mongo-tools" do
      inreplace "build.sh", '-ldflags "-X github.com/mongodb/mongo-tools/common/options.Gitspec `git rev-parse HEAD`"', ""

      args = %W[]

      if build.with? "openssl"
        args << "ssl"
        ENV["LIBRARY_PATH"] = "#{Formula["openssl"].opt_prefix}/lib"
        ENV["CPATH"] = "#{Formula["openssl"].opt_prefix}/include"
      end
      system "./build.sh", *args
    end

    mkdir "src/mongo-tools"
    cp Dir["src/github.com/mongodb/mongo-tools/bin/*"], "src/mongo-tools/"

    args = %W[
      --prefix=#{prefix}
      -j#{ENV.make_jobs}
      --osx-version-min=#{MacOS.version}
      --cc=#{ENV.cc}
      --cxx=#{ENV.cxx}
      --use-new-tools
      --disable-warnings-as-errors
    ]

    if build.with? "openssl"
      args << "--ssl"
      args << "--extrapath=#{Formula["openssl"].opt_prefix}"
    end

    scons "install", *args

    (buildpath + "mongod.conf").write mongodb_conf
    etc.install "mongod.conf"

    (var + "mongodb").mkpath
    (var + "log/mongodb").mkpath
  end

  def mongodb_conf
    <<-CONF.undent
      systemLog:
        destination: file
        path: #{var}/log/mongodb/mongo.log
        logAppend: true
      storage:
        dbPath: #{var}/mongodb
      net:
        bindIp: 127.0.0.1
    CONF
  end

  plist_options manual: "mongod --config #{HOMEBREW_PREFIX}/etc/mongod.conf"

  def plist
    <<-PLIST.undent
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/mongod</string>
          <string>--config</string>
          <string>#{etc}/mongod.conf</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/mongodb/output.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/mongodb/output.log</string>
        <key>HardResourceLimits</key>
        <dict>
          <key>NumberOfFiles</key>
          <integer>4096</integer>
        </dict>
        <key>SoftResourceLimits</key>
        <dict>
          <key>NumberOfFiles</key>
          <integer>4096</integer>
        </dict>
      </dict>
      </plist>
    PLIST
  end

  test do
    system "#{bin}/mongod", "--sysinfo"
  end
end
