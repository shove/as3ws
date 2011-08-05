
task :default => :build

def run cmd
  puts cmd
  puts `#{cmd}`
end

task :build do
  
  build = [
    "mxmlc",
    "-static-link-runtime-shared-libraries",
    "-target-player=10.2",
    "-output=../shove/lib/proxy.swf",
    "src/WebSocketProxy.as"
  ]
  
  run build.join(" ")
    
end
