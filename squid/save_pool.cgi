#!/usr/local/bin/perl
# save_pool.cgi
# Create, update or delete a delay pool

require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
&error_setup($text{'pool_err'});

@pools = &find_config("delay_class", $conf);
@params = &find_config("delay_parameters", $conf);
@access = &find_config("delay_access", $conf);
$pools = &find_config("delay_pools", $conf);
$pools = { 'name' => 'delay_pools' } if (!$pools);
if (!$in{'new'}) {
	($pool) = grep { $_->{'values'}->[0] == $in{'idx'} } @pools;
	($param) = grep { $_->{'values'}->[0] == $in{'idx'} } @params;
	}
else {
	$pool = { 'name' => 'delay_class',
		  'values' => [ $pools->{'values'}->[0] + 1 ] };
	$param = { 'name' => 'delay_parameters',
		   'values' => [ $pools->{'values'}->[0] + 1 ] };
	}

if ($in{'delete'}) {
	# When deleting, the numbers of any pools 'above' it must be shifted
	# down, any delay_access directives removed and the delay_pools count
	# decreased
	@access = grep { $_->{'values'}->[0] != $in{'idx'} } @access;
	@pools = grep { $_ ne $pool } @pools;
	@params = grep { $_ ne $param } @params;
	map { $_->{'values'}->[0]-- if ($_->{'values'}->[0] > $in{'idx'}) } 
		(@access, @pools, @params);
	&save_directive($conf, "delay_class", \@pools);
	&save_directive($conf, "delay_parameters", \@params);
	&save_directive($conf, "delay_access", \@access);
	$pools->{'values'}->[0]--;
	&save_directive($conf, "delay_pools", [ $pools ]);
	}
else {
	# Validate and store inputs
	$pool->{'values'}->[1] = $in{'class'};
	if ($in{'class'} == 1) {
		@v = ( &parse_limit("agg") );
		}
	elsif ($in{'class'} == 2) {
		@v = ( &parse_limit("agg"), &parse_limit("ind") );
		}
	elsif ($in{'class'} == 3) {
		@v = ( &parse_limit("agg"), &parse_limit("net"),
		       &parse_limit("ind") );
		}
	elsif ($in{'class'} == 4) {
		@v = ( &parse_limit("agg"), &parse_limit("net"),
		       &parse_limit("ind"), &parse_limit("user") );
		}
	elsif ($in{'class'} == 5) {
		@v = ( &parse_limit("tag") );
		}
	$param->{'values'} = [ $param->{'values'}->[0], @v ];

	if ($in{'new'}) {
		# Add the pool and increment the count
		$pools->{'values'}->[0]++;
		push(@pools, $pool);
		push(@params, $param);
		&save_directive($conf, "delay_pools", [ $pools ]);
		}
	&save_directive($conf, "delay_class", \@pools);
	&save_directive($conf, "delay_parameters", \@params);
	&save_directive($conf, "delay_access", \@access);
	}

&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "pool", $in{'idx'}, \%in);
&redirect("edit_delay.cgi");

# parse_limit(name)
sub parse_limit
{
if ($in{"$_[0]_def"}) {
	return "-1/-1";
	}
else {
	local @ud = ( .125, 1, 125, 1000, 125000, 1000000 );
	local $u1 = $in{"$_[0]_1_n"};
	local $u2 = $in{"$_[0]_2_n"};
	$u1 =~ /^\d+$/ || $u1 == -1 || &error(&text('pool_elimit1', $u1));
	$u2 =~ /^\d+$/ || $u2 == -1 || &error(&text('pool_elimit2', $u2));
	$u1 = int($u1 * $ud[$in{"$_[0]_1_u"}]);
	$u2 = int($u2 * $ud[$in{"$_[0]_2_u"}]);
	return "$u1/$u2";
	}
}

