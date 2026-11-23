<?php
require_once dirname(__DIR__).'/other/_functions.php';

function check_address($expected, $config) {
    $actual = public_ts_address($config);
    if ($actual !== $expected) {
        throw new RuntimeException("Expected $expected, got $actual");
    }
}

$config = ['teamspeak_host_address' => 'localhost', 'teamspeak_voice_port' => '9987'];
$_SERVER['HTTP_HOST'] = 'www.example.org:8443';
check_address('example.org:9987', $config);
$_SERVER['HTTP_HOST'] = '[2001:db8::7]:8080';
check_address('[2001:db8::7]:9987', $config);
unset($_SERVER['HTTP_HOST']);
check_address('localhost:9987', $config);

$config['teamspeak_host_address'] = '2001:db8::5';
check_address('[2001:db8::5]:9987', $config);
$config['teamspeak_public_address'] = 'voice.example.org';
check_address('voice.example.org:9987', $config);
$config['teamspeak_public_address'] = '[2001:db8::9]:10987';
check_address('[2001:db8::9]:10987', $config);
$config['teamspeak_public_address'] = 'voice.example.org:65536';
check_address('[2001:db8::5]:9987', $config);
