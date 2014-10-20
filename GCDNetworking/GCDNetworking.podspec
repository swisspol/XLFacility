# http://guides.cocoapods.org/syntax/podspec.html
# http://guides.cocoapods.org/making/getting-setup-with-trunk.html
# $ sudo gem update cocoapods
# (optional) $ pod trunk register {email} {name} --description={computer}
# $ pod trunk push
# DELETE THIS SECTION BEFORE PROCEEDING!

Pod::Spec.new do |s|
  s.name     = 'GCDNetworking'
  s.version  = '1.0'
  s.author   =  { 'Pierre-Olivier Latour' => 'info@pol-online.net' }
  s.license  = { :type => 'BSD', :file => 'LICENSE' }
  s.homepage = 'https://github.com/swisspol/GCDNetworking'
  s.summary  = 'Networking framework based on GCD'

  s.source   = { :git => 'https://github.com/swisspol/GCDNetworking.git', :tag => s.version.to_s }
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  s.requires_arc = true

  s.source_files = 'GCDNetworking/*.{h,m}'
  s.private_header_files = "GCDNetworking/*Private.h"
  s.requires_arc = true
  s.ios.frameworks = 'CFNetwork'

end
