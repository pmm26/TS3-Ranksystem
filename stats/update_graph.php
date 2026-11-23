<?PHP
ini_set('session.cookie_httponly', 1);
ini_set('session.use_strict_mode', 1);
if(in_array('sha512', hash_algos())) {
	ini_set('session.hash_function', 'sha512');
}
if(isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == "on") {
	ini_set('session.cookie_secure', 1);
	if(!headers_sent()) {
		header("Strict-Transport-Security: max-age=31536000; includeSubDomains; preload;");
	}
}
session_start();

header("Content-Type: application/json; charset=UTF-8");

require_once('../other/_functions.php');
require_once('../other/config.php');

// Each period uses the newest real sample in each chart interval.
$periods = array(
	'day'    => array(1, 15),
	'week'   => array(7, 30),
	'month'  => array(30, 60),
	'3month' => array(90, 240)
);
$period = $_GET['serverusagechart'] ?? 'day';
if (!is_string($period) || !isset($periods[$period])) {
	$period = 'day';
}
list($days, $interval_minutes) = $periods[$period];
$interval_seconds = $interval_minutes * 60;

$server_usage = $mysqlcon->prepare("SELECT `timestamp`, `clients`, `channel`
	FROM `$dbname`.`server_usage`
	WHERE `timestamp` BETWEEN UNIX_TIMESTAMP() - ? AND UNIX_TIMESTAMP()
	ORDER BY `timestamp` DESC");
$server_usage->execute(array($days * 86400));

$chart_data = array();
$last_interval = null;
while ($chart_value = $server_usage->fetch(PDO::FETCH_ASSOC)) {
	$interval = intdiv((int)$chart_value['timestamp'], $interval_seconds);
	if ($interval === $last_interval) {
		continue;
	}
	$last_interval = $interval;
	$chart_data[] = array(
		"y" => date('Y-m-d H:i',$chart_value['timestamp']),
		"a" => $chart_value['clients'],
		"b" => $chart_value['channel']
	);
}

echo json_encode($chart_data);
?>