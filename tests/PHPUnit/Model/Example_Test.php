<?php
require_once __DIR__ .'/../Model_TestCase.php';



/**
 * An example test
 */
class Model_Example_Test extends Model_TestCase {



	//////////
	// config
	//////////

	protected $object_name = 'Model_Example';



	//////////
	// methods
	//////////

	public function __construct() {
		if (false === parent::__construct()) return false;
		return true;
	}



	/**
	 * Sets up the fixture, for example, opens a network connection.
	 * This method is called before a test is executed.
	 */
	protected function setUp() {
		if (false === parent::setUp()) return false;
		return true;
	}



	/**
	 * Tears down the fixture, for example, closes a network connection.
	 * This method is called after a test is executed.
	 */
	protected function tearDown() {
		if (false === parent::tearDown()) return false;
		return true;
	}



	/**
	 * Test something
	 */
	public function test_true_is_true() {
		$this->assertTrue(true);
		return true;
	}


}	// end class
