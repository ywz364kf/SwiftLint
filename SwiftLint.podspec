Pod::Spec.new do |s|
  s.name                      = 'SwiftLint'
  s.version                   = '0.54.0'
  s.summary                   = 'A tool to enforce Swift style and conventions.'
  s.homepage                  = 'https://github.com/ywz364kf/SwiftLint'
  s.license                   = { type: 'MIT', file: 'LICENSE' }
  s.author                    = { 'JP Simard' => 'jp@jpsim.com' }
  s.source                    = { http: "#{s.homepage}/releases/download/#{s.version}/portable_swiftlint.zip" }
  s.preserve_paths            = '*'
  s.exclude_files             = '**/file.zip'
  s.ios.deployment_target     = '11.0'
  s.macos.deployment_target   = '10.13'
  s.tvos.deployment_target    = '11.0'
  s.watchos.deployment_target = '7.0'
  s.visionos.deployment_target = '1.0'
end
