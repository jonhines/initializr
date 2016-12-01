require 'bundler/setup'
require 'rake'

gitBranch = ENV['GIT_BRANCH'] || 'branch_unknown'
buildNumber = ENV['BUILD_NUMBER'] || 65535
baseVersion = `mvn -q -Dexec.executable="echo" -Dexec.args='\${project.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.3.1:exec`.strip
version = ENV['Docker_Image'] || "#{baseVersion}.#{buildNumber}"
imageRepo = "<DOCKER_REPO_URL_HERE>"
image = "#{imageRepo}/CONTAINER_NAME"


puts "BUILD_VERSION: #{version}"

task :info do
  puts "BUILD_VERSION: #{version}"
end

desc "Build war and Docker image and publish war to artifactory and docker image to our docker registry"
task :build, [:dockerEnabled] do |t, args|
  begin
    sh("mvn versions:set -DnewVersion=#{version}")
    dockerEnabled = args[:dockerEnabled] || true
    if (sh("docker --version") && dockerEnabled)

      # If we're not on master tag with the branch name instead of the version number
      imageTag = (version if (gitBranch == 'origin/master')) || gitBranch

      # Need to pull the java image dependencies explicitly
      sh("docker pull #{imageRepo}/java-alpine:1.0.2")

      sh("mvn clean package docker:build -DimageTag=#{imageTag}")

      # Don't push if there's no build number (i.e. not on the build machine)
      if ((!(buildNumber == 65535)) && (gitBranch == 'origin/master'))
        sh("mvn sonar:sonar")
        sh("docker push #{image}:#{imageTag}")
      end
    else
      sh("mvn clean package")
    end
    sh("mvn versions:revert")
  rescue
    sh("mvn versions:revert")
  end
end

desc "Deploy to specified environment on aws"
task :deploy, [:environment] do |t, args|
  environment=args[:environment] || "local"
  sh("sh deploy/deployment.sh deploy #{environment} #{version}")
end