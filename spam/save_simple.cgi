#!/usr/local/bin/perl
# Update simple tests

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("header");
$conf = &get_config();
&error_setup($text{'simple_err'});
&execute_before("simple");

# Get existing rules
@simples = &get_simple_tests($conf);
@headers = &find("header", $conf);
@bodies = &find("body", $conf);
@fulls = &find("full", $conf);
@uris = &find("uri", $conf);
@scores = &find("score", $conf);
@describes = &find("describe", $conf);

# Parse and validate inputs
for($i=0; defined($name = $in{"name_$i"}); $i++) {
	$simple = $i < @simples ? $simples[$i] : undef;
	if ($simple) {
		# Take out the directives that would be replaced
		@headers = grep { $_ ne $simple->{'header_dir'} } @headers;
		@bodies = grep { $_ ne $simple->{'body_dir'} } @bodies;
		@fulls = grep { $_ ne $simple->{'full_dir'} } @fulls;
		@uris = grep { $_ ne $simple->{'uri_dir'} } @uris;
		@scores = grep { $_ ne $simple->{'score_dir'} } @scores;
		@describes = grep { $_ ne $simple->{'describe_dir'} } @describes;
		}

	if ($name) {
		$name =~ /^\S+$/ || &error(&text('header_ename', $name));
		$donename{$name}++ && &error(&text('header_eclash', $name));
		$header = $in{"header_$i"};
		$regexp = $in{"regexp_$i"};
		$regexp || &error(&text('header_eregexp2', $name));
		$flags = $in{"flags_$i"};
		$flags =~ /^[a-z]*$/ || &error(&text('header_eflags', $flags));
		$score = $in{"score_$i"};
		$score eq "" || $score =~ /^\-?\d+(\.\d+)?$/ ||
				$score =~ /^\-?\.\d+$/ ||
			&error(&text('score_epoints', $score));
		$describe = $in{"describe_$i"};

		# Update or add the actual directives
		if ($header eq "body") {
			push(@bodies, { 'name' => 'body',
				       'value' => "$name /$regexp/$flags" });
			}
		elsif ($header eq "full") {
			push(@fulls, { 'name' => 'full',
				       'value' => "$name /$regexp/$flags" });
			}
		elsif ($header eq "uri") {
			push(@uris, { 'name' => 'uri',
				       'value' => "$name /$regexp/$flags" });
			}
		else {
			my $ucheader = ucfirst($header);
			push(@headers, { 'name' => 'header',
				         'value' => "$name $ucheader =~ /$regexp/$flags" });
			}

		# Update the score and describe
		if ($score ne "") {
			push(@scores, { 'name' => 'score',
					'value' => "$name $score" });
			}
		if ($describe ne "") {
			push(@describes, { 'name' => 'describe',
					   'value' => "$name $describe" });
			}
		}
	}

# Save the directives
&lock_spam_files();
&save_directives($conf, "header", \@headers, 0);
&save_directives($conf, "body", \@bodies, 0);
&save_directives($conf, "full", \@fulls, 0);
&save_directives($conf, "score", \@scores, 0);
&save_directives($conf, "describe", \@describes, 0);
&save_directives($conf, "uri", \@uris, 0);

&flush_file_lines();
&unlock_spam_files();
&execute_after("header");
&webmin_log("header");
&redirect($redirect_url);

