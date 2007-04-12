#!/usr/local/bin/perl
# atboot.pl
# Called by setup.sh to have webmin started at boot time

$no_acl_check++;
require './init-lib.pl';
$product = $ARGV[0] || "webmin";
$ucproduct = ucfirst($product);

if ($init_mode eq "osx") {
	# Darwin System
	&open_tempfile(LOCAL, ">>$config{'hostconfig'}");
	&print_tempfile(LOCAL, "WEBMIN=-YES-\n");
	&close_tempfile(LOCAL);
	
	$paramlist = "$config{'darwin_setup'}/$ucproduct/$config{'plist'}";
	$scriptfile = "$config{'darwin_setup'}/$ucproduct/$ucproduct";
	
	# On a Virgin darwin system, $config{'darwin_setup'} may not yet exist
	-d "$config{'darwin_setup'}/$ucproduct" || do {
		if ( -d "$config{'darwin_setup'}" ) {
			mkdir ("$config{'darwin_setup'}/$ucproduct", 0755);
			} else {
			mkdir ("$config{'darwin_setup'}", 0755);
			mkdir ("$config{'darwin_setup'}/$ucproduct",0755);
			}
		} until -d "$config{'darwin_setup'}/$ucproduct";

	&open_tempfile(PLIST, ">$paramlist");
	&print_tempfile(PLIST, "{\n");
	&print_tempfile(PLIST, "\t\tDescription\t\t= \"$ucproduct system administration daemon\";\n");
	&print_tempfile(PLIST, "\t\tProvides\t\t= (\"$ucproduct\");\n");
	&print_tempfile(PLIST, "\t\tRequires\t\t= (\"Resolver\");\n");
	&print_tempfile(PLIST, "\t\tOrderPreference\t\t= \"None\";\n");
	&print_tempfile(PLIST, "\t\tMessages =\n");
	&print_tempfile(PLIST, "\t\t{\n");
	&print_tempfile(PLIST, "\t\t\tstart\t= \"Starting $ucproduct Server\";\n");
	&print_tempfile(PLIST, "\t\t\tstop\t= \"Stopping $ucproduct Server\";\n");
	&print_tempfile(PLIST, "\t\t};\n");
	&print_tempfile(PLIST, "}\n");
	&close_tempfile(PLIST);

	# Create Bootup Script
	&open_tempfile(STARTUP, ">$scriptfile");
	&print_tempfile(STARTUP, "#!/bin/sh\n\n");
	&print_tempfile(STARTUP, ". /etc/rc.common\n\n");
	&print_tempfile(STARTUP, "if [ \"\${WEBMIN:=-NO-}\" = \"-YES-\" ]; then\n");
	&print_tempfile(STARTUP, "\tConsoleMessage \"Starting $ucproduct\"\n");
	&print_tempfile(STARTUP, "\t$config_directory/start >/dev/null 2>&1 </dev/null\n");
	&print_tempfile(STARTUP, "fi\n");
	&close_tempfile(STARTUP);
	chmod(0750, $scriptfile);
	}
elsif ($init_mode eq "local") {
	# Add to the boot time rc script
	$lref = &read_file_lines($config{'local_script'});
	for($i=0; $i<@$lref && $lref->[$i] !~ /^exit\s/; $i++) { }
	splice(@$lref, $i, 0, "$config_directory/start >/dev/null 2>&1 </dev/null # Start $ucproduct");
	&flush_file_lines();
	print STDERR "Added to bootup script $config{'local_script'}\n";
	}
elsif ($init_mode eq "init") {
	# Create a bootup action
	@start = &get_start_runlevels();
	$fn = &action_filename($product);
	&open_tempfile(ACTION,">$fn");
	$desc = "Start/stop $ucproduct";
	&print_tempfile(ACTION, "#!/bin/sh\n");
	$start_order = "9" x $config{'order_digits'};
	$stop_order = "9" x $config{'order_digits'};
	if ($config{'chkconfig'}) {
		# Redhat-style description: and chkconfig: lines
		&print_tempfile(ACTION, "# description: $desc\n");
		&print_tempfile(ACTION, "# chkconfig: $config{'chkconfig'} ",
			     "$start_order $stop_order\n");
		}
	elsif ($config{'init_info'}) {
		# Suse-style init info section
		&print_tempfile(ACTION, "### BEGIN INIT INFO\n",
			     "# Provides: $product\n",
			     "# Required-Start: \$network \$syslog\n",
			     "# Required-Stop: \$network\n",
			     "# Default-Start: ",join(" ", @start),"\n",
			     "# Description: $desc\n",
			     "### END INIT INFO\n");
		}
	else {
		# Just description in a comment
		&print_tempfile(ACTION, "# $desc\n");
		}
	&print_tempfile(ACTION, "\n");
	&print_tempfile(ACTION, "case \"\$1\" in\n");

	&print_tempfile(ACTION, "'start')\n");
	&print_tempfile(ACTION, "\t$config_directory/start >/dev/null 2>&1 </dev/null\n");
	&print_tempfile(ACTION, "\tRETVAL=\$?\n");
	if ($config{'subsys'}) {
		&print_tempfile(ACTION, "\tif [ \"\$RETVAL\" = \"0\" ]; then\n");
		&print_tempfile(ACTION, "\t\ttouch $config{'subsys'}/$product\n");
		&print_tempfile(ACTION, "\tfi\n");
		}
	&print_tempfile(ACTION, "\t;;\n");

	&print_tempfile(ACTION, "'stop')\n");
	&print_tempfile(ACTION, "\t$config_directory/stop\n");
	&print_tempfile(ACTION, "\tRETVAL=\$?\n");
	if ($config{'subsys'}) {
		&print_tempfile(ACTION, "\tif [ \"\$RETVAL\" = \"0\" ]; then\n");
		&print_tempfile(ACTION, "\t\trm -f $config{'subsys'}/$product\n");
		&print_tempfile(ACTION, "\tfi\n");
		}
	&print_tempfile(ACTION, "\t;;\n");

	&print_tempfile(ACTION, "'status')\n");
	&print_tempfile(ACTION, "\tpidfile=`grep \"^pidfile=\" $config_directory/miniserv.conf | sed -e 's/pidfile=//g'`\n");
	&print_tempfile(ACTION, "\tif [ -s \$pidfile ]; then\n");
	&print_tempfile(ACTION, "\t\tpid=`cat \$pidfile`\n");
	&print_tempfile(ACTION, "\t\tkill -0 \$pid >/dev/null 2>&1\n");
	&print_tempfile(ACTION, "\t\tif [ \"\$?\" = \"0\" ]; then\n");
	&print_tempfile(ACTION, "\t\t\techo \"$product (pid \$pid) is running\"\n");
	&print_tempfile(ACTION, "\t\t\tRETVAL=0\n");
	&print_tempfile(ACTION, "\t\telse\n");
	&print_tempfile(ACTION, "\t\t\techo \"$product is stopped\"\n");
	&print_tempfile(ACTION, "\t\t\tRETVAL=1\n");
	&print_tempfile(ACTION, "\t\tfi\n");
	&print_tempfile(ACTION, "\telse\n");
	&print_tempfile(ACTION, "\t\techo \"$product is stopped\"\n");
	&print_tempfile(ACTION, "\t\tRETVAL=1\n");
	&print_tempfile(ACTION, "\tfi\n");
	&print_tempfile(ACTION, "\t;;\n");

	&print_tempfile(ACTION, "'restart')\n");
	&print_tempfile(ACTION, "\t$config_directory/stop ; $config_directory/start\n");
	&print_tempfile(ACTION, "\tRETVAL=\$?\n");
	&print_tempfile(ACTION, "\t;;\n");

	&print_tempfile(ACTION, "*)\n");
	&print_tempfile(ACTION, "\techo \"Usage: \$0 { start | stop }\"\n");
	&print_tempfile(ACTION, "\tRETVAL=1\n");
	&print_tempfile(ACTION, "\t;;\n");
	&print_tempfile(ACTION, "esac\n");
	&print_tempfile(ACTION, "exit \$RETVAL\n");
	&close_tempfile(ACTION);
	chmod(0755, $fn);

	# Add whatever links are needed to start at boot
	&enable_at_boot($product);
	print STDERR "Created init script $fn\n";
	}
elsif ($init_mode eq "win32") {
	# Create win32 service
	$perl_path = &get_perl_path();
	&enable_at_boot($product, $ucproduct, $perl_path." ".&quote_path("$root_directory/miniserv.pl")." ".&quote_path("$config_directory/miniserv.conf"));
	}
elsif ($init_mode eq "rc") {
	# Create RC script
	&enable_at_boot($product, $ucproduct, "$config_directory/start",
					      "$config_directory/stop");
	}

$config{'atboot_product'} = $product;
&save_module_config();

