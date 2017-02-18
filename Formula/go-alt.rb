class GoAlt < Formula
  desc "The Go programming language"
  homepage "https://golang.org"

  stable do
    url "https://storage.googleapis.com/golang/go1.8.src.tar.gz"
    mirror "https://fossies.org/linux/misc/go1.8.src.tar.gz"
    version "1.8"
    sha256 "406865f587b44be7092f206d73fc1de252600b79b3cacc587b74b5ef5c623596"

    go_version = version.to_s.split(".")[0..1].join(".")
    resource "gotools" do
      url "https://go.googlesource.com/tools.git",
          :branch => "release-branch.go#{go_version}",
          :revision => "12a9eeeaa0fb4dc5c00e510411b39ab6e4b8796b"
    end
  end

  head do
    url "https://go.googlesource.com/go.git"

    resource "gotools" do
      url "https://go.googlesource.com/tools.git"
    end
  end

  if OS.mac?
    option "without-cgo", "Build without cgo (also disables race detector)"
    option "without-race", "Build without race detector"
  end
  option "without-godoc", "godoc will not be installed for you"

  depends_on :macos => :mountain_lion

  resource "gobootstrap" do
    if OS.mac?
      url "https://storage.googleapis.com/golang/go1.8.darwin-amd64.tar.gz"
      sha256 "6fdc9f98b76a28655a8770a1fc8197acd8ef746dd4d8a60589ce19604ba2a120"
    elsif OS.linux?
      url "https://storage.googleapis.com/golang/go1.8.linux-amd64.tar.gz"
      sha256 "53ab94104ee3923e228a2cb2116e5e462ad3ebaeea06ff04463479d7f12d27ca"
    end
    version "1.8"
  end

  def os
    OS.mac? ? "darwin" : "linux"
  end

  def install
    ENV.permit_weak_imports

    (buildpath/"gobootstrap").install resource("gobootstrap")
    ENV["GOROOT_BOOTSTRAP"] = buildpath/"gobootstrap"

    cd "src" do
      ENV["GOROOT_FINAL"] = libexec
      ENV["GOOS"]         = os

      # Fix error: unknown relocation type 42; compiled without -fpic?
      # See https://github.com/Linuxbrew/linuxbrew/issues/1057
      ENV["CGO_ENABLED"]  = "0" if build.without?("cgo") || OS.linux?
      system "./make.bash", "--no-clean"
    end

    (buildpath/"pkg/obj").rmtree
    rm_rf "gobootstrap" # Bootstrap not required beyond compile.
    libexec.install Dir["*"]
    bin.install_symlink Dir[libexec/"bin/go*"]

    # Race detector only supported on amd64 platforms.
    # https://golang.org/doc/articles/race_detector.html
    if build.with?("cgo") && build.with?("race") && MacOS.prefer_64_bit?
      system bin/"go", "install", "-race", "std"
    end

    if build.with? "godoc"
      ENV.prepend_path "PATH", bin
      ENV["GOPATH"] = buildpath
      (buildpath/"src/golang.org/x/tools").install resource("gotools")

      if build.with? "godoc"
        cd "src/golang.org/x/tools/cmd/godoc/" do
          system "go", "build"
          (libexec/"bin").install "godoc"
        end
        bin.install_symlink libexec/"bin/godoc"
      end
    end
  end

  def caveats; <<-EOS.undent
    As of go 1.2, a valid GOPATH is required to use the `go get` command:
      https://golang.org/doc/code.html#GOPATH

    You may wish to add the GOROOT-based install location to your PATH:
      export PATH=$PATH:#{opt_libexec}/bin
    As of go 1.8, the default GOPATH is: ~/go/
    EOS
  end

  test do
    (testpath/"hello.go").write <<-EOS.undent
    package main

    import "fmt"

    func main() {
        fmt.Println("Hello World")
    }
    EOS
    # Run go fmt check for no errors then run the program.
    # This is a a bare minimum of go working as it uses fmt, build, and run.
    system bin/"go", "fmt", "hello.go"
    assert_equal "Hello World\n", shell_output("#{bin}/go run hello.go")

    if build.with? "godoc"
      assert File.exist?(libexec/"bin/godoc")
      assert File.executable?(libexec/"bin/godoc")
    end

    if build.with? "cgo"
      ENV["GOOS"] = "freebsd"
      system bin/"go", "build", "hello.go"
    end
  end
end
