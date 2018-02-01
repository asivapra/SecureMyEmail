#!/usr/local/bin/perl
# 01/02/2018: 2
use Net::Telnet ();
$t = new Net::Telnet (Telnetmode => 0, Timeout => 60);
sub do_main_0
{
    $t->open(Host => $server, Port => 25);
	$command = "telnet $server 25";
#&debug ("command = $command",1);
#	$message .= "<i>$command</i>\n";
    ## Wait for first prompt and "hit return".
    ($prompt) = $t->waitfor('/\n/');
#	$message .= "<font color=\"$fontcolor1\"> $prompt</font>\n";
	$command = "helo $helo";
#	$message .= "<i>$command</i>\n";
    $t->print("$command");
    ## Wait for second prompt and respond with city code.
    ($prompt) = $t->waitfor('/\n/');
#	$message .= "<font color=\"$fontcolor1\"> $prompt</font>\n";
	$command = "mail from: $envFrom";
#	$message .= "<i>$command</i>\n";
    $t->print("$command");
	$command = "rcpt to: $item";
#	$message .= "<i>$command</i>\n";
#&debug ("Test2 = $message");	
	$t->print("$command");
#print "command: $command; \n";	
	($prompt) = $t->waitfor('/\n/i');
#print "prompt = $prompt;\n";	
#	$message .= "<font color=\"$fontcolor1\"> $prompt</font>\n";
	$command = "data";
#	$message .= "$command\n";
    $t->print("$command");
#&debug ("Test3 = $message");	
    ($prompt) = $t->waitfor('/\n/i');
#	$message .= "<font color=\"$fontcolor1\"> $prompt</font>\n";
	$command = "From: $hdrFrom";
#	$message .= "<i>$command</i>\n";
    $t->print("$command");
#&debug ("Test3 = $message");	
	$command = "To: $hdrTo";
#	$message .= "<i>$command</i>\n";
    $t->print("$command");

    open(INP,"<11690853583");
    @filecontent = <INP>;
    close (INP);
    $len = $#filecontent;
print "len = $len\n";    
    #Skip the header
#    for ($j=0; $j <= $len; $j++)
#    {
#    	if ($filecontent[$j] eq "\n")
#    	{
##    		$filecontent[$j] = "";
#    		last;
#    	}
##    	$filecontent[$j] = "";
#    }
    $command = "";
    for ($j++; $j <= $len; $j++)
    {
    	$command .= $filecontent[$j];
    }
    $command .= "\.";
    $t->print("$command");
print "command = $command\n";    
#&debug ("Test3 = $message");	
#	$command = "Subject: $subject";
##	$message .= "<i>$command</i>\n";
#   $t->print("$command");
#	$command = "\.";
##	$message .= "<i>$command</i>\n";
#    $t->print("$command");
#    ($prompt) = $t->waitfor('/\n/i');
###	$message .= "<font color=\"$fontcolor1\"> $prompt</font>\n";
	print $message;
}
sub GetRandomChars
{
	$n = $_[0];
	$alphanumeric = '1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
	@alphanumeric = split (//, $alphanumeric);
	$randomString = "";
	for (my $j=0; $j <= $n; $j++)
	{
		srand;  # Seed the random number
		$i = int (rand (62));  # Get a random start position
		$randomString .= $alphanumeric[$i];
	}
	return $randomString;
}

sub SendMailFile
{
    open(INP,"<11690853583");
    @filecontent = <INP>;
    close (INP);
    $len = $#filecontent;
    $command = "";
    for ($j=0; $j <= $len; $j++)
    {
    	$command .= $filecontent[$j];
    }
    $command .= "\.";
    $t->print("$command");
}
sub SendCommandLineMail
{
	$command = "From: $hdrFrom\n";
    $command .= "To: $hdrTo\n";
    $command .= "X-Passed-By: webgenie.com\n";
#    $command .= "Cc: $envFrom\n";
    $command .= "Subject: $subject\n";
    $command .= "$subject\n";
    $command .= "\.";
    $t->print("$command");
   ($prompt) = $t->waitfor('/\n/i');
    $t->print("$command");
print "subject = $subject to $envTo; hdrTo = $hdrTo\n";    
}
sub do_main
{

    $t->open(Host => $server, Port => 25);
	$command = "telnet $server 25";
    ($prompt) = $t->waitfor('/\n/');
	$command = "helo $helo";
    $t->print("$command");
    ($prompt) = $t->waitfor('/\n/');

	$command = "mail from: $envFrom";  # This can be the HdrFrom or a hard coded address
    $t->print("$command");
	$command = "rcpt to: $envTo";  # This is the clean mail address
	$t->print("$command");
	($prompt) = $t->waitfor('/\n/i');

	$command = "data";
    $t->print("$command");
    ($prompt) = $t->waitfor('/\n/i');

    $msgID = &GetRandomChars(40);

	$command = "Message-Id: <" . $msgID . "\@" . $hostName . ">";
	$t->print("$command");
   ($prompt) = $t->waitfor('/\n/i');

#	&SendMailFile;
	&SendCommandLineMail;
}
$hostName = "smtp.exonmail.com"; # mail.exonmail.com
$ipAddr = "209.239.112.136"; # mail.exonmail.com
#$server = "209.239.112.110"; # mail.webgenie.com
$server = "localhost"; # mail.webgenie.com
#$server = "216.38.49.94"; # mail.constructzero.com
$helo = "exonmail.com";
#$envFrom = 'noreply@startdedicated.com';
$envFrom = 'support@webgenie.com';
#$envFrom = 'gat@simpleology.com'; # Blocked address
$envTo = 'promo@webgenie.com';
#$envTo = 'avs_webgenie.com@exonmail.com';
#$envTo = 'tsthill@webgenie.com';
#$envTo = 'avs2904@webgenie.com';
#$envTo = 'avs@constructzero.com';
#$envTo = 'asivapra@gmail.com';
#$envTo = 'avs_webgenie.com@exonmail.com';
$hdrFrom = 'support@webgenie.com';
#$hdrTo = 'avs2904@webgenie.com';
#$hdrFrom = 'support@exxonmail.com';
#$hdrFrom = 'gat@simpleology.com'; # Blocked address
#$hdrTo = 'asivapra@gmail.com';
$hdrTo = 'promo@webgenie.com';
#$hdrTo = 'avs_webgenie.com@exonmail.com';
$subject = "Test Sending Alert from Exonmail: " . $$;
&do_main;
sleep(1);

