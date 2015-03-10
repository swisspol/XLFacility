# http://guides.cocoapods.org/syntax/podspec.html
# http://guides.cocoapods.org/making/getting-setup-with-trunk.html
# $ sudo gem update cocoapods
# (optional) $ pod trunk register {email} {name} --description={computer}
# $ pod trunk push
# DELETE THIS SECTION BEFORE PROCEEDING!

Pod::Spec.new do |s|
  s.name     = 'GCDTelnetServer'
  s.version  = '1.1.2'
  s.author   =  { 'Pierre-Olivier Latour' => 'info@pol-online.net' }
  s.license  = { :type => 'BSD', :file => 'LICENSE' }
  s.homepage = 'https://github.com/swisspol/GCDTelnetServer'
  s.summary  = 'Drop-in embedded Telnet server for iOS and OS X apps'

  s.source   = { :git => 'https://github.com/swisspol/GCDTelnetServer.git', :tag => s.version.to_s }
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  s.requires_arc = true

  s.subspec 'GCDNetworking' do |cs|
    cs.source_files = 'GCDNetworking/GCDNetworking/*.{h,m}'
    cs.private_header_files = "GCDNetworking/GCDNetworking/*Private.h"
    cs.requires_arc = true
    cs.ios.frameworks = 'CFNetwork'
  end

  s.subspec 'Core' do |cs|
    cs.dependency 'GCDTelnetServer/GCDNetworking'
    s.source_files = 'GCDTelnetServer/*.{h,m}'
    s.private_header_files = "GCDTelnetServer/*Private.h"
    cs.requires_arc = true
  end

end
