#!/usr/local/bin/perl
# Delete, enable or disable repositories

require './package-updates-lib.pl';
&ReadParse();
$mode = $in{'disable'} ? 'disable' :
	$in{'enable'} ? 'enable' :
	$in{'delete'} ? 'delete' : undef;
$mode || &error($text{'repos_ebutton'});
&error_setup($text{'repos_err_'.$mode});
%d = map { $_, 1 } split(/\0/, $in{'d'});

# Get the repos being updated
@repos = &software::list_package_repos();
@delrepos = grep { $d{$_->{'id'}} } @repos;
@delrepos || &error($text{'repos_enone'});
@delrepos = sort { $b->{'line'} <=> $a->{'line'} } @delrepos;

if ($mode eq 'enable' || $mode eq 'disable') {
	# Enable or disable
	foreach my $repo (@delrepos) {
		&software::enable_package_repo($repo, $mode eq 'enable');
		}
	if (@delrepos == 1) {
		&webmin_log($mode, 'repo', $delrepos[0]->{'id'});
		}
	else {
		&webmin_log($mode, 'repos', scalar(@delrepos));
		}
	&redirect("index.cgi?tab=repos");
	}
else {
	# Delete, but ask first
	if ($in{'confirm'}) {
		foreach my $repo (@delrepos) {
			&software::delete_package_repo($repo);
			}
		if (@delrepos == 1) {
			&webmin_log('delete', 'repo', $delrepos[0]->{'id'});
			}
		else {
			&webmin_log('delete', 'repos', scalar(@delrepos));
			}
		&redirect("index.cgi?tab=repos");
		}
	else {
		&ui_print_header(undef, $text{'repos_title'}, "");

		print &ui_confirmation_form(
			"save_repos.cgi",
			&text('repos_rusure', scalar(@delrepos)),
			[ [ 'delete', 1 ],
			  map { [ 'd', $_->{'id'} ] } @delrepos,
			],
			[ [ 'confirm', $text{'repos_ok'} ] ],
			);

		&ui_print_footer("index.cgi?tab=repos",
				 $text{'index_return'});
		}
	}

