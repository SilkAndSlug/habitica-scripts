<?php
/** 
 * Export the current database to a file in e.g. ./data/backups/database/.
 * Designed to be used with e.g. wGet
 * 
 * Admin only. Exports the database using mySQLdump, and returns a value.
 * 
 * @todo	move functions to functions/ or models/
 * @todo	move main() to function or method
 * @todo	Check 'master user' has Lock Table privilege, else call function
 */



////////
// init
////////

// bootstrap
ini_set('display_errors',1);
error_reporting(E_ALL);


require_once(__DIR__ .'/includes/initialise.php');


// test for Safe Mode
// @todo	move to FrameWork|initialise.php
$is_safe_mode = false;
if (ini_get('safe_mode')) {
	$is_safe_mode = true;
}
define('IS_SAFE_MODE', (bool) $is_safe_mode);
if ($_GET['debug'] >= SILK_VERBOSE) echo '_export::IS_SAFE_MODE ', (IS_SAFE_MODE), EOL;


// test for mySQLdump
if (!function_exists('is_command_available')) { echo "Can't find function::is_command_available", EOL; exit(1); }
if (true !== is_command_available('which')) { echo "Can't find `which`"; exit(1); }
define('IS_MYSQLDUMP_AVAILABLE', is_command_available('mysqldump'));



////////
// config
////////

define('DROP_TABLE', false);
define('IS_PIPING', false);	// can the OS pipe mySQLdump into a file?

define('SINK_FILE', 'data/backups/database/'. SERVER .'-'. date('Ymd-His') .'.sql');



////////
// access-control
////////

if (!IS_SILK_DEV) {
	echo "You must be an admin to see this page.";
	exit(1);	// end execution
}


// we're now admin-only, so show *all* errors.
ini_set('display_errors',1);
error_reporting(E_ALL & ~E_DEPRECATED);



////////
// assertions
////////

// session
if (!defined('SESSION_PREFIX')) { echo 'SESSION_PREFIX not defined'; exit(1); }


// database
if (!defined('MYSQL_SUPERUSER_USERNAME') AND defined('MYSQL_USERNAME')) define('MYSQL_SUPERUSER_USERNAME', MYSQL_USERNAME);
if (!defined('MYSQL_SUPERUSER_PASSWORD') AND defined('MYSQL_PASSWORD')) define('MYSQL_SUPERUSER_PASSWORD', MYSQL_PASSWORD);

if (!defined('MYSQL_SERVER')) { echo 'MYSQL_SERVER not defined'; exit(1); }
if (!defined('MYSQL_DATABASE')) { echo 'MYSQL_DATABASE not defined'; exit(1); }
if (!defined('MYSQL_SUPERUSER_USERNAME')) { echo 'MYSQL_SUPERUSER_USERNAME not defined'; exit(1); }
if (!defined('MYSQL_SUPERUSER_PASSWORD')) { echo 'MYSQL_SUPERUSER_PASSWORD not defined'; exit(1); }


// sink dir
define('SINK_DIR', dirname(SINK_FILE));
if (!(file_exists(SINK_DIR))) {
	mkdir(SINK_DIR, 02777, true);
}

if ($_GET['debug'] >= SILK_DEBUG) echo 'file_exists', file_exists(SINK_DIR), EOL;
if ($_GET['debug'] >= SILK_DEBUG) echo 'is_dir', is_dir(SINK_DIR), EOL;
if ($_GET['debug'] >= SILK_DEBUG) echo 'is_writable', is_writable(SINK_DIR), EOL;
if (!(file_exists(SINK_DIR) AND is_dir(SINK_DIR) AND is_writable(SINK_DIR))) {
	echo 'Cannot find and/or write to ', SINK_DIR, EOL;
	exit(1);	// end execution
}



////////
// main()
////////

//Export the database and output the status to the page
if (!(isset($_SESSION[SESSION_PREFIX]) AND is_array($_SESSION[SESSION_PREFIX]) AND count($_SESSION[SESSION_PREFIX]) >= 0)) {
	$_SESSION[SESSION_PREFIX] = array();
}
if (!(isset($_SESSION[SESSION_PREFIX]['_export']) AND is_array($_SESSION[SESSION_PREFIX]['_export']) AND count($_SESSION[SESSION_PREFIX]['_export']) >= 0)) {
	$_SESSION[SESSION_PREFIX]['_export'] = array();
}
if (!(isset($_SESSION[SESSION_PREFIX]['_export']['filename']) AND is_string($_SESSION[SESSION_PREFIX]['_export']['filename']) AND strlen($_SESSION[SESSION_PREFIX]['_export']['filename']) > 0)) {
	$_SESSION[SESSION_PREFIX]['_export']['filename'] = SINK_FILE;
}


// export the database to file
$status = 0;
if (IS_MYSQLDUMP_AVAILABLE) {
	$command='mysqldump --host="' . MYSQL_SERVER .'" --user="' . MYSQL_SUPERUSER_USERNAME .'" --password="'. MYSQL_SUPERUSER_PASSWORD .'" "'. MYSQL_DATABASE .'"';
	if (IS_PIPING) {
		// send output directly to SINK_FILE
		$command .= ' > '. SINK_FILE .'';
	}
	if ($_GET['debug'] >= SILK_DEBUG) echo '_export::command ', ($command), EOL;


	$output = array();
	exec($command, $output, $status);
	if ($_GET['debug'] >= SILK_DEBUG) echo '_export::output <pre>', print_r($output, true), '</pre>', EOL;


	if (!IS_PIPING) {
		// save output to SINK_FILE
		$output = implode(PHP_EOL, $output);
		file_put_contents(SINK_FILE, $output);
	}


} else {
	$is_exported = export_database_to_file(SINK_FILE);
	if ($_GET['debug'] >= SILK_DEBUG) echo '_export::is_exported ', ($is_exported), EOL;
	if (!$is_exported) {
		$status = 2;
	}
}
if ($_GET['debug'] >= SILK_DEBUG) echo '_export::status ', ($status), EOL;


switch($status) {
	case 0:
		$message = 'Database <b>' . MYSQL_DATABASE .'</b> successfully exported to <b>'. SINK_FILE .'</b>'. EOL;
		if (!(file_exists(SINK_FILE) AND is_file(SINK_FILE))) {
			$message .= "WARNING: Backup-function reports success, but ". SINK_FILE ." doesn't exist or isn't readable". EOL;
		}
		break;
	case 1:
		$message = 'There was a warning during the export of <b>' . MYSQL_DATABASE .'</b> to <b>'. SINK_FILE .'</b>'. EOL;
		break;
	case 2:
		$message = 'There was an error during export. Please check your values:'. EOL. '<table><tr><td>MySQL Database Name:</td><td><b>' . MYSQL_DATABASE .'</b></td></tr><tr><td>MySQL User Name:</td><td><b>'. MYSQL_SUPERUSER_USERNAME .'</b></td></tr><tr><td>MySQL Password:</td><td><b>NOTSHOWN</b></td></tr><tr><td>MySQL Host Name:</td><td><b>'. MYSQL_SERVER .'</b></td></tr></table>'. EOL;
		break;
	case 3:
		echo 'There was a CONSCHECK Error during the export of <b>' . MYSQL_DATABASE .'</b> to <b>'. SINK_FILE .'</b>';
		break;
	case 4:
		echo 'There was a EOM (out of memory?) Error during the export of <b>' . MYSQL_DATABASE .'</b> to <b>'. SINK_FILE .'</b>';
		break;
	case 5:
		echo 'There was a EOF (out of disk-space?) Error during the export of <b>' . MYSQL_DATABASE .'</b> to <b>'. SINK_FILE .'</b>';
		break;
	case 6:
		echo 'There was an Illegal Table Error during the export of <b>' . MYSQL_DATABASE .'</b> to <b>'. SINK_FILE .'</b>. Please change IS_PIPING to false, and try again.';
		break;
}
echo $message, EOL;


if ($_GET['debug'] >= SILK_INFO) {
	$filesize = filesize(SINK_FILE);
	echo "export::filesize ", ($filesize), EOL;
	echo "WARNING: there may be a delay between running this script and the filesize updating; check before you panic!", EOL;
}


exit(0);	// end execution



/**
 * Crawls the database, outputting (DROP+)CREATE+INSERT sql
 * 
 * Based on the script at:
 * http://blog.aajit.com/exportbackup-mysql-database-like-phpmyadmin/
 * 
 * 
 * @todo	Tests!
 * 
 * 
 * @param	string	$path		Where to store the backup file, relative to the calling file. Defaults to SINK_FILE
 * @returns	bool				False on failure, else true.
 */
function export_database_to_file($filename = SINK_FILE) {
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_database_to_file::filename ', ($filename), EOL;
	if (!(isset($filename) AND is_string($filename) AND strlen($filename) > 0)) return false;


	if ($_GET['debug'] >= SILK_INFO) echo 'Preparing backup process...', EOL;


	// is file valid?
	if (!(file_exists($filename) AND is_file($filename))) {
		touch($filename);
		chmod($filename, 0777);
	}
	if (!(file_exists($filename) AND is_file($filename) AND is_writable($filename))) return false;


	// connect to database
	if ($_GET['debug'] >= SILK_INFO) echo 'Connecting to database...', EOL;

	$db = connect_to_database_as_superuser();
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_database_to_file::db ', get_resource_type($db), EOL;
	if (!(is_resource($db) AND 'mysql link' === get_resource_type($db))) return false;

	if ($_GET['debug'] >= SILK_INFO) echo 'Connected', EOL;



	////////
	// backup
	////////

	if ($_GET['debug'] >= SILK_INFO) echo 'Loading data...', EOL;

	// get all auto-increment values for later
	$auto_increments = array();
	if ((isset($_SESSION[SESSION_PREFIX]['_export']['auto_increments']) AND is_array($_SESSION[SESSION_PREFIX]['_export']['auto_increments']) AND count($_SESSION[SESSION_PREFIX]['_export']['auto_increments']) > 0)) {
		$auto_increments = $_SESSION[SESSION_PREFIX]['_export']['auto_increments'];
	}
	if (!(isset($auto_increments) AND is_array($auto_increments) AND count($auto_increments) > 0)) {
		$table_status_result = mysql_query("SHOW TABLE STATUS", $db);
		if (false === $table_status_result) return false;

		while (false !== ($row = mysql_fetch_assoc($table_status_result))) {
			if (!(isset($row['Name']))) continue;
			if (!(isset($row['Auto_increment']))) continue;
			$auto_increments[$row['Name']] = $row['Auto_increment'];
		}

		$_SESSION[SESSION_PREFIX]['_export']['auto_increments'] = $auto_increments;
	}
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_database_to_file::auto_increments <pre>', print_r($auto_increments, true), '</pre>', EOL;
	if (!(isset($auto_increments) AND is_array($auto_increments) AND count($auto_increments) > 0)) return false;


	// get all table info for later
	$tables = get_tables_data($db);
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_database_to_file::tables <pre>', print_r($tables, true), '</pre>', EOL;
	if (!(isset($tables) AND is_array($tables) AND count($tables) > 0)) return false;
	$_SESSION[SESSION_PREFIX]['_export']['tables'] = $tables;


	if ($_GET['debug'] >= SILK_INFO) echo 'Loaded', EOL;


	if ($_GET['debug'] >= SILK_VERBOSE) echo EOL;


	if ($_GET['debug'] >= SILK_INFO) echo 'Saving...', EOL;
	if ($_GET['debug'] >= SILK_INFO) echo 'There are ', count($tables), ' tables', EOL;


	// finally, write to file
	$is_okay = export_tables_to_file($tables, $db, $filename);
	if (true !== $is_okay) return false;


	if ($_GET['debug'] >= SILK_INFO) echo 'Exported all tables', EOL;


	// tidy & exit
	if ($_GET['debug'] >= SILK_INFO) echo 'Backup Complete', EOL;

	return true;
}	// end function



/**
 * Tests if the given command is in the path. Before using, call is_command_available('which').
 * 
 * @param	string		$command	Command to test-for, e.g. which
 * @return	bool					False on failure or if unavailable, else true
 */
function is_command_available($command = '') {
	if (!(isset($command) AND is_string($command) AND strlen($command) > 0)) return false;

	$command = 'which '. $command;
	if ($_GET['debug'] >= SILK_DEBUG) echo 'is_command_available::command ', ($command), EOL;

	$status = 0;
	$output = array();
	@exec($command, $output, $status);
	if ($_GET['debug'] >= SILK_DEBUG) echo 'is_command_available::status ', ($status), EOL;
	if ($_GET['debug'] >= SILK_DEBUG) echo 'is_command_available::output <pre>', print_r($output, true), '</pre>', EOL;

	if (0 !== $status) return false;
	return true;
}	// end function



function connect_to_database_as_superuser() {
	$db = mysql_connect(MYSQL_SERVER, MYSQL_SUPERUSER_USERNAME, MYSQL_SUPERUSER_PASSWORD);
	if (!(is_resource($db) AND 'mysql link' === get_resource_type($db))) return false;

	$is_selected = mysql_select_db(MYSQL_DATABASE, $db);
	if (false === $is_selected) return false;

	return $db;
}	// end function



/**
 * Fetch details of the database's tables, as an array
 * 
 * @param	resource	$db		MySQL connction
 * @return	bool|array			False on failure, else list of assoc. arrays containing tables and their info
 */
function get_tables_data($db = '') {
	if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::db ', get_resource_type($db), EOL;
	if (!(isset($db) AND is_resource($db) AND 'mysql link' === get_resource_type($db))) return false;


	// get tables from cache
	if ((isset($_SESSION[SESSION_PREFIX]['_export']['tables']) AND is_array($_SESSION[SESSION_PREFIX]['_export']['tables']) AND count($_SESSION[SESSION_PREFIX]['_export']['tables']) > 0)) {
		//return $_SESSION[SESSION_PREFIX]['_export']['tables'];
	}


	// get tables from DB
	$sql = "SHOW TABLES FROM `". MYSQL_DATABASE ."`";
	if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::sql ', ($sql), EOL;
	$tables_result = mysql_query($sql, $db);
	if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::mysql_error ', mysql_error($db), EOL;
	if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::tables_result ', get_resource_type($tables_result), EOL;
	if (!(isset($tables_result) AND is_resource($tables_result) AND 'mysql result' === get_resource_type($tables_result))) return false;


	// loop through tables
	$tables = array();
	while (false !== ($row = mysql_fetch_row($tables_result))) {
		if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::row <pre>', print_r($row, true), '</pre>', EOL;
		if (!(isset($row[0]) AND is_string($row[0]) AND strlen($row[0]) > 0)) continue;


		$table = array();


		$table['name'] = $row[0];


		$table['rows_done'] = 0;


		$table['rows_total'] = 0;
		$sql = "SELECT COUNT(*) AS rows_total FROM `${table['name']}`";
		if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::sql <pre>', ($sql), '</pre>', EOL;
		$this_result = mysql_query($sql, $db);
		if (isset($this_result) AND is_resource($this_result) AND 'mysql result' === get_resource_type($this_result)) {
			$this_row = mysql_fetch_assoc($this_result);
			if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::this_row <pre>', print_r($this_row, true), '</pre>', EOL;

			if (!(isset($this_row) AND is_array($this_row) AND count($this_row) >= 0)) $this_row = array();

			if (!(isset($this_row['rows_total']) AND is_numeric($this_row['rows_total']) AND ((int) $this_row['rows_total']) >= 0)) $this_row['rows_total'] = 0;
			if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::this_row <pre>', print_r($this_row, true), '</pre>', EOL;

			$table['rows_total'] = (int) $this_row['rows_total'];
		}	// end if rows
		$this_result = $this_row = false;


		$table['completed'] = false;
		if ($table['rows_done'] >= $table['rows_total']) {
			$table['completed'] = true;
		}


		if ($_GET['debug'] >= SILK_DEBUG) echo 'get_tables_data::table <pre>', print_r($table, true), '</pre>', EOL;
		$tables[] = $table;
	}	// end while tables
	$tables_result = $row = false;


	return $tables;
}	// end function



/**
 * Fetch table structure & data and write to SINK_FILE
 * 
 * @todo	extract export_table_data_to_file
 * @todo	INSERT INTO `table` (`fields`) VALUES (...),(...);
 * 
 * @param	array	$tables		List of tables, as per get_tables_data
 * @param	resource	$db		MySQL connection
 * @return	bool				False on failure, else true
 */
function export_tables_to_file($tables = array(), $db = '', $filename = SINK_FILE) {
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_tables_to_file::tables <pre>', print_r($tables, true), '</pre>', EOL;
	if (!(isset($tables) AND is_array($tables) AND count($tables) > 0)) return false;

	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_tables_to_file::db ', get_resource_type($db), EOL;
	if (!(isset($db) AND is_resource($db) AND 'mysql link' === get_resource_type($db))) return false;



	/*
	 * The export may time-out while we're still building it. To manage that,
	 * we export each table in turn, and we cache a list of tables-done so we
	 * don't duplicate ourselves.
	 */
	foreach ($tables AS $table) {
		if ($_GET['debug'] >= SILK_DEBUG) echo 'export_tables_to_file::table <pre>', print_r($table, true), '</pre>', EOL;


		$table_name = $table['name'];
		if ($_GET['debug'] >= SILK_DEBUG) echo 'export_tables_to_file::table_name ', ($table_name), EOL;

		if ($table['completed']) {
			if ($_GET['debug'] >= SILK_INFO) echo 'Table ', ($table_name), ' already complete; skipping', EOL;
			continue;
		}

		if ($_GET['debug'] >= SILK_INFO) echo 'Saving table ', ($table_name), '...', EOL;


		// output table structure
		if (0 === $table['rows_done']) {
			export_table_to_file($table, $db, $filename);
			export_table_data_header_to_file($table, $filename);
		}	// end if first time we've seen this table


		// @todo	list column names
		// @todo	walk array, implode
		// @todo	output records in slices of c.1000 rows
		$sql = "SELECT * FROM `$table_name`";
		$rows_done = 0;
		$string = '';
		$result = mysql_query($sql, $db);
		while (false !== ($row = mysql_fetch_assoc($result))) {
			if ($_GET['debug'] >= SILK_DEBUG) echo 'export_tables_to_file::row <pre>', print_r($row, true), '</pre>', EOL;


			$values = array();
			foreach ($row AS $key => $var) {
				$values[] = "'$key' = '". mysql_real_escape_string ($var, $db). "'";
			}
			$string .= "INSERT INTO `$table_name` VALUES(". implode(', ', $values) .");". PHP_EOL;


			$rows_done++;
		}	// end result
		$result = $row = false;

		if (!write_string_to_file($string, $filename)) return false;

		//	@todo	 increment $_SESSION[SESSION_PREFIX][??]['rows_done']
		$table['rows_done'] += $rows_done;


		// footer
		export_table_data_footer_to_file($filename);


		$_SESSION[SESSION_PREFIX]['_export']['completed_tables'][] = $table_name;

		if ($_GET['debug'] >= SILK_INFO) echo 'Exported table ', ($table_name), EOL;
	}	// end foreach table


	return true;
}	// end function



/**
 * Fetch the structure of a single table and append it to SINK_FILE
 * 
 * @param	array	$tables		List of tables, as per get_tables_data
 * @param	resource	$db		MySQL connection
 * @return	bool				False on failure, else true
 */
function export_table_to_file($table = array(), $db = null, $filename = SINK_FILE) {
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_table_to_file::table <pre>', print_r($table, true), '</pre>', EOL;
	if (!(isset($table) AND is_array($table) AND count($table) > 0)) return false;

	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_table_to_file::db ', get_resource_type($db), EOL;
	if (!(isset($db) AND is_resource($db) AND 'mysql link' === get_resource_type($db))) return false;


	if (!(isset($table['name']) AND is_string($table['name']) AND strlen($table['name']) > 0)) return false;
	$table_name = $table['name'];


	$string = '';

	$string .= "--". PHP_EOL;
	$string .= "-- Table structure for `$table_name`". PHP_EOL;
	$string .= "--". PHP_EOL;
	$string .= PHP_EOL;

	if (DROP_TABLE) {
		$string .= "DROP IF EXISTS TABLE `$table_name`;". PHP_EOL;
	}

	$result = mysql_query("SHOW CREATE TABLE `$table_name`", $db);
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_table_to_file::result ', get_resource_type($result), EOL;
	if (!(isset($result) AND is_resource($result) AND 'mysql result' === get_resource_type($result))) return false;

	while (false !== ($row = mysql_fetch_assoc($result))) {
		if ($_GET['debug'] >= SILK_DEBUG) echo 'export_table_to_file::row <pre>', print_r($row, true), '</pre>', EOL;
		if (!(isset($row['Create Table']) AND is_string($row['Create Table']) AND strlen($row['Create Table']) > 0)) continue;

		$this_string = $row['Create Table'];

		// insert 'if not exists'
		$this_string = str_replace("CREATE TABLE ", "CREATE TABLE IF NOT EXISTS ", $this_string);

		// add auto-increment
		if (isset($auto_increments[$table_name])) {
			$this_string .= $this_string." AUTO_INCREMENT = ". $auto_increments[$table_name] .";";
		}

		$string .= $this_string .';'. PHP_EOL;
	}
	$result = $row = false;
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_table_to_file::string <pre>', ($string), '</pre>', EOL;


	$string .= PHP_EOL;
	$string .= PHP_EOL;


	if (!write_string_to_file($string, $filename)) return false;

	return true;
}	// end function



/**
 * Fetch the structure of a single table and append it to SINK_FILE
 * 
 * @param	array	$tables		List of tables, as per get_tables_data
 * @param	resource	$db		MySQL connection
 * @return	bool				False on failure, else true
 */
function export_table_data_header_to_file($table = array(), $filename = SINK_FILE) {
	if ($_GET['debug'] >= SILK_DEBUG) echo 'export_table_data_header_to_file::table <pre>', print_r($table, true), '</pre>', EOL;
	if (!(isset($table) AND is_array($table) AND count($table) > 0)) return false;


	if (!(isset($table['name']) AND is_string($table['name']) AND strlen($table['name']) > 0)) return false;
	$table_name = $table['name'];

	$string = '';
	$string .= "--". PHP_EOL;
	$string .= "-- Data to be inserted into table `$table_name`". PHP_EOL;
	$string .= "--". PHP_EOL;
	$string .= PHP_EOL;


	if (!write_string_to_file($string, $filename)) return false;

	return true;
}


function export_table_data_footer_to_file($filename = SINK_FILE) {
	$string = '';
	$string .= PHP_EOL;
	$string .= PHP_EOL;
	$string .= "-- --------------------------------------------------------". PHP_EOL;
	$string .= PHP_EOL;

	if (!write_string_to_file($string, $filename)) return false;

	return true;
}


function write_string_to_file($string = '', $filename = SINK_FILE) {
	if ($_GET['debug'] >= SILK_DEBUG) echo 'write_string_to_file::strlen ', strlen($string), EOL;
	if (!(isset($string) AND is_string($string) AND strlen($string) > 0)) return false;

	if ($_GET['debug'] >= SILK_DEBUG) echo 'write_string_to_file::filename ', ($filename), EOL;
	if (!(isset($filename) AND is_string($filename) AND strlen($filename) > 0)) return false;


	// open
	$fh = fopen($filename, 'a') or die("Backup not done! file error");
	if ($_GET['debug'] >= SILK_DEBUG) echo 'write_string_to_file::fh ', get_resource_type($fh), EOL;
	if (!(isset($fh) AND is_resource($fh) AND 'stream' === get_resource_type($fh))) return false;

	// write
	if (!fwrite($fh, $string)) return false;

	// close
	fclose($fh);
	$fh = false;


	return true;
}	// end function
