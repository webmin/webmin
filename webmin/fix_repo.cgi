#!/usr/local/bin/perl
# Fix the Webmin repository URL and key

require './webmin-lib.pl';
&ReadParse();

if (-r $webmin_yum_repo_file) {
	# Fix up YUM repo
	&lock_file($webmin_yum_repo_file);
	my $lref = &read_file_lines($webmin_yum_repo_file);
	foreach my $l (@$lref) {
		if ($l =~ /^\s*baseurl\s*=\s*(\S+)/) {
			$l = "baseurl=".$webmin_yum_repo_url;
			}
		elsif ($l =~ /^\s*mirrorlist\s*=\s*(\S+)/) {
			$l = "mirrorlist=".$webmin_yum_repo_mirrorlist;
			}
		elsif ($l =~ /^\s*gpgkey\s*=\s*file:\/\/(\S+)/) {
			&copy_source_dest(
			    "$module_root_directory/developers-key.asc",
			    $webmin_yum_repo_key)
				if (!-r $webmin_yum_repo_key);
			$l = "gpgkey=file://".$webmin_yum_repo_key;
			}
		}
	&flush_file_lines($webmin_yum_repo_file);
	&unlock_file($webmin_yum_repo_file);
	&system_logged("rpm --import $webmin_yum_repo_key >/dev/null 2>&1 </dev/null");
	}

foreach my $repo ($webmin_apt_repo_file, $global_apt_repo_file) {
	# Fix APT repo
	next if (!-r $repo);
	&lock_file($repo);
	my $lref = &read_file_lines($repo);
	foreach my $l (@$lref) {
		if ($l =~ /^\s*deb\s+((http|https):\/\/download.webmin.com\/download\/repository)\s+sarge\s+contrib/) {
			$l = "deb $webmin_apt_repo_url stable contrib";
			}
		elsif ($l =~ /^\s*deb\s+\[signed-by=(\S+)\]\s+((http|https):\/\/download.webmin.com\/download\/repository)\s+sarge\s+contrib/) {
			$l = "deb [signed-by=$webmin_apt_repo_key] $webmin_apt_repo_url stable contrib";
			}
		}
	&flush_file_lines($repo);
	&unlock_file($repo);
	# XXX import key
	}

&webmin_log("fixrepo");
&redirect(get_referer_relative());
