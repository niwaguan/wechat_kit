#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint wechat_kit.podspec` to validate before publishing.
#

# 加载pubspec.yaml文件
pubspec = YAML.load_file(File.join('..', 'pubspec.yaml'))
# 获取版本号
library_version = pubspec['version'].gsub('+', '-')

# 获取当前目录
current_dir = Dir.pwd
# 获取调用目录
calling_dir = File.dirname(__FILE__)
# 获取项目目录
project_dir = calling_dir.slice(0..(calling_dir.index('/.symlinks')))
# 获取flutter项目目录
flutter_project_dir = calling_dir.slice(0..(calling_dir.index('/ios/.symlinks')))
# 加载pubspec.yaml文件
cfg = YAML.load_file(File.join(flutter_project_dir, 'pubspec.yaml'))
# 判断是否使用no_pay
if cfg['wechat_kit'] && cfg['wechat_kit']['ios'] == 'no_pay'
  wechat_kit_subspec = 'no_pay'
else
  wechat_kit_subspec = 'pay'
end
# 输出wechatsdk
Pod::UI.puts "wechatsdk #{wechat_kit_subspec}"
# 如果cfg存在wechat_kit对象，并且包wechat_kit对象中含from_env，则执行环境变量同步过程
if cfg['wechat_kit'] && cfg['wechat_kit']['from_env']
  # 获取环境变量
  wechat_kit_env = cfg['wechat_kit']['from_env']
  app_id_key = wechat_kit_env['app_id_key']
  universal_link_key = wechat_kit_env['universal_link_key']
  flavors = wechat_kit_env['flavors']
  flavors.each do |flavor|
    content = File.read(File.join(flutter_project_dir, flavor['src']))
    app_id_line = content.each_line.find { |line| line.start_with?(app_id_key) }
    universal_link_line = content.each_line.find { |line| line.start_with?(universal_link_key) }
    next if !app_id_line || !universal_link_line

    tos = flavor['ios']
    tos.each do |to|
      path = File.join(project_dir, "Flutter/#{to}")
      con = File.read(path)

      if con.include?("#{app_id_key}=")
        con.gsub!(/#{app_id_key}=.*/, app_id_line.chomp(''))
      else
        con += app_id_line
      end
      key, universal_link = universal_link_line.chomp('').split('=', 2)
      universal_link_host = URI.parse(universal_link).host
      if con.include?("#{universal_link_key}=")
        con.gsub!(/#{universal_link_key}=.*/, "#{key}=#{universal_link_host}")
      else
        con += "#{key}=#{universal_link_host}\n"
      end
      File.write(path, con)
    end
  end
  system("ruby #{current_dir}/wechat_setup.rb -k #{app_id_key} -l #{universal_link_key} -p #{project_dir} -n Runner.xcodeproj")
  # 判断是否使用app_id和universal_link
elsif cfg['wechat_kit'] && (cfg['wechat_kit']['app_id'] && cfg['wechat_kit']['universal_link'])
  # 获取app_id
  app_id = cfg['wechat_kit']['app_id']
  # 获取universal_link
  universal_link = cfg['wechat_kit']['universal_link']
  # 调用wechat_setup.rb文件
  system("ruby #{current_dir}/wechat_setup.rb -a #{app_id} -u #{universal_link} -p #{project_dir} -n Runner.xcodeproj")
else
  # 输出提示信息
  abort("wechat app_id/universal_link is null, add code in pubspec.yaml:\nwechat_kit:\n  app_id: ${your wechat app id}\n  universal_link: https://${your applinks domain}/universal_link/${example_app}/wechat/\n")
end

Pod::Spec.new do |s|
  s.name             = 'wechat_kit'
  s.version          = library_version
  s.summary          = pubspec['description']
  s.description      = pubspec['description']
  s.homepage         = pubspec['homepage']
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # s.default_subspecs = :none
  s.default_subspecs = wechat_kit_subspec, 'vendor'

  s.subspec 'pay' do |sp|
    sp.vendored_frameworks = 'Libraries/Pay/*.xcframework'
  end

  s.subspec 'no_pay' do |sp|
    sp.vendored_frameworks = 'Libraries/NoPay/*.xcframework'
    sp.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => 'NO_PAY=1',
    }
  end

  s.subspec 'vendor' do |sp|
    sp.frameworks = 'CoreGraphics', 'Security', 'WebKit'
    sp.libraries = 'c++', 'z', 'sqlite3.0'
    sp.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -ObjC -all_load',
    }
  end

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
