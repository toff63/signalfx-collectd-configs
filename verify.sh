type md5sum > /dev/null 2>&1 || (echo "this script needs md5sum to execute"; exit 1)

doit() {
	url=$1
        dlsfx=`curl -s "https://dl.signalfx.com/$url" | md5sum`
        s3=`curl -s "https://s3.amazonaws.com/public-downloads--signalfuse-com/$url" | md5sum`
	if [ ! "$s3" = "$dlsfx" ]; then
		echo "$url doesn't match $s3 $dlsfx"
	fi
}

for stage in beta test release; do
	#debian
	for debian in wheezy jessie; do
		ppa="debs/collectd/$debian/${stage}"
		doit $ppa/Packages
	done
	if [ "$stage" = "test" ]; then
		for ubuntu in vivid precise trusty; do
			ppa="debs/collectd/$ubuntu/${stage}"
			doit $ppa/Packages
		done
	fi

	#rpm file variables
	centos_rpm="SignalFx-collectd-RPMs-centos-${stage}-latest.noarch.rpm"
	aws_linux_rpm="SignalFx-collectd-RPMs-AWS_EC2_Linux-${stage}-latest.noarch.rpm"

	#download location variables
	centos="rpms/SignalFx-rpms/${stage}/${centos_rpm}"
	aws_linux="rpms/SignalFx-rpms/${stage}/${aws_linux_rpm}"
	doit $centos
	doit $aws_linux
	for os in AWS_EC2_Linux-2014.09 AWS_EC2_Linux-2015.03 AWS_EC2_Linux-2015.09 AWS_EC2_Linux-latest centos-6 centos-7; do
		repo="rpms/collectd/$stage/$os/x86_64/repodata/repomd.xml"
		doit $repo
	done
done
