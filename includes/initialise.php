<?php
/**
 * Load configs & standard constants
 */



////////
// bootstrap
////////

// show all errors
ini_set('display_errors', 'on');
error_reporting(E_ALL);


ob_start();
session_start();


require_once(__DIR__ .'/definitions.php');


$key = 'debug';	// workaround for hook:grep
if (!(isset($_GET[$key]))) {
	$_GET[$key] = SILK_QUIET;
}



////////
// define environment
////////

// Silk Framework uses SERVER to choose between config files
// SERVER := DEV|QA|LIVE
if (!defined('SERVER')) {
	$server = 'LIVE';
	if (
		(false !== stripos($_SERVER['SCRIPT_NAME'], '/qa/'))
		OR (false !== stripos($_SERVER['SCRIPT_NAME'], '/remote/'))
	) {
		$server = 'QA';
	} else if (false !== stripos($_SERVER['SCRIPT_NAME'], '/dev/')) {
		$server = 'DEV';
	}
	define('SERVER', $server);
}
if ($_GET['debug'] >= SILK_DEBUG) echo 'initialise::SERVER ', (SERVER), EOL;


// assert SERVER = DEV|QA|LIVE
if (
	!defined('SERVER')
	OR (
		'LIVE' !== SERVER
		AND 'QA' !== SERVER
		AND 'DEV' !== SERVER
	)
) {
	throw new Exception('SERVER must be defined as LIVE, QA, or DEV. Unable to continue');
}


// command line?
$is_CLI = false;
if ('cli' === php_sapi_name()) {
	$is_CLI = true;
}
define('IS_CLI', $is_CLI);



////////
// load functions, classes
////////

require_once(__DIR__ .'/config-all.php');


// load functions
$dir = __DIR__ .'/../functions';
if (file_exists($dir) AND is_dir($dir) AND is_readable($dir)) {
	foreach (glob('functions/*.php') AS $file) {
		require_once $file;
	}
}


// load composer
$file = __DIR__ .'/../vendor/autoload.php';
if (file_exists($file) AND is_file($file) AND is_readable($file)) {
	require_once $file;
}



////////
// configure as per the environment
////////

// error reporting
switch (SERVER) {
	case 'DEV':
		ini_set('display_errors', 'on');
		error_reporting(-1);	// show everything
		break;

	case 'QA':
		ini_set('display_errors', 'off');
		error_reporting(0);
		if ($_GET['debug'] >= SILK_DEBUG) {
			ini_set('display_errors', 'on');
			error_reporting(E_ALL & ~E_DEPRECATED);	// don't show deprecated
		}
		break;

		case 'LIVE':
	default:
		ini_set('display_errors', 'off');
		error_reporting(0);
		break;
}


// load config
switch (SERVER) {
	case 'LIVE':
	default:
		require_once(__DIR__ .'/config-live.php');
		break;

	case 'QA':
		require_once(__DIR__ .'/config-qa.php');
		break;

	case 'DEV':
		require_once(__DIR__ .'/config-dev.php');
		break;
}


// switch EOL character per environment
$EOL = PHP_EOL;
if (!IS_CLI) {
	$EOL = HTML_EOL;
}
define('EOL', $EOL);
