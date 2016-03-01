Pod::Spec.new do |s|
  s.name             = "RZDataBinding"
  s.version          = "2.0.3"
  s.summary          = "KVO extensions that help maintain data integrity in your iOS or OSX app"
  s.description      = <<-DESC
                       Add callbacks when key paths of objects change, or bind values of two objects together either directly or using a function. Automatically cleanup before deallocation to avoid those nasty KVO observation info leaks.
                       DESC
  s.homepage         = "https://github.com/Raizlabs/RZDataBinding"
  s.license          = 'MIT'
  s.author           = { "Rob Visentin" => "rob.visentin@raizlabs.com" }
  s.source           = { :git => "https://github.com/Raizlabs/RZDataBinding.git", :tag => s.version.to_s }

  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.requires_arc = true

  s.source_files = 'RZDataBinding'
end
