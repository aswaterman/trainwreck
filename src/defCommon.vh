`ifndef DEF_COMMON_V
`define DEF_COMMON_V

// Define a start time for when RTL assertion checking should begin.
// This avoids assertion checks which fail before the model is reset
// into a valid state.  Note, we assume a 10 ns clock period.
 `define ERROR_CHECK_START_TIME 100

//-------------------------------------------------------------------
// Basic error macros
//-------------------------------------------------------------------

 `define RTL_ERROR(msg) \
    if ($time > `ERROR_CHECK_START_TIME) \
      $display( " RTL-ERROR ( time = %d ) %m : %s", $time, msg ) \

 `define RTL_WARNING(msg) \
    if ($time > `ERROR_CHECK_START_TIME) \
      $display( " RTL-WARNING ( time = %d ) %m : %s", $time, msg ) \
    
 `define RTL_ERROR_1ARG(msg, arg1) \
    if ($time > `ERROR_CHECK_START_TIME) \
      $display( " RTL-ERROR ( time = %d ) %m : %s : 0x%0x", $time, msg, arg1 ) \
    
 `define RTL_ERROR_2ARG(msg, arg1, arg2) \
    if ($time > `ERROR_CHECK_START_TIME) \
      $display( " RTL-ERROR ( time = %d ) %m : %s : 0x%0x 0x%0x", $time, msg, arg1, arg2 ) \

//-------------------------------------------------------------------
// Basic assert and error checking macros
//-------------------------------------------------------------------
    
 `define RTL_ASSERT(goodcond, msg) \
    if (goodcond); \
    else `RTL_ERROR( {"assertion failed : ", msg} ) \
	
 `define RTL_ASSERT_1ARG(goodcond, msg, arg1) \
    if (goodcond); \
    else `RTL_ERROR( {"assertion failed : ",msg}, arg1 ) \
	
 `define RTL_ASSERT_2ARG(goodcond, msg, arg1, arg2) \
    if (goodcond); \
    else `RTL_ERROR_2ARG( {"assertion failed : ",msg}, arg1, arg2 ) \
	
 `define RTL_ASSERT_POSEDGE(clk, goodcond, msg) \
    always @(posedge clk) \
      `RTL_ASSERT( goodcond, msg )
  	    
 `define RTL_ERRCHK(badcond, msg) \
    if (!(badcond)); \
    else `RTL_ERROR( msg ) \

 `define RTL_ERRCHK_1ARG(badcond, msg, arg1) \
    if (!(badcond)); \
    else `RTL_ERROR_1ARG( msg, arg1 ) \

 `define RTL_ERRCHK_2ARG(badcond, msg, arg1, arg2) \
    if (!(badcond)); \
    else `RTL_ERROR_2ARG( msg, arg1, arg2 ) \

 `define RTL_ERRCHK_POSEDGE(clk, badcond, msg) \
    always @(posedge clk) \
      `RTL_ERRCHK( badcond, msg )
	    
 `define RTL_ERRCHK_NEGEDGE(clk, badcond, msg) \
    always @(negedge clk) \
      `RTL_ERRCHK( badcond, msg )

//-------------------------------------------------------------------
// X handling macros
//-------------------------------------------------------------------
  
 `define RTL_PROPAGATE_X(i, o) \
    if ((|((i) ^ (i))) == 1'b0); \
    else o = o + 1'bx
	    
 `define RTL_ASSERT_NOT_X_MSG(net, msg) \
    if ((|((net) ^ (net))) == 1'b0); \
    else `RTL_ERROR( {"x assertion failed : ",msg} ) \
	
 `define RTL_ASSERT_NOT_X_ALWAYS_MSG(net, msg) \
    always @* \
      `RTL_ASSERT_NOT_X_MSG(net, msg)
	
 `define RTL_ASSERT_NOT_X_POSEDGE_MSG(clk, net, msg) \
    always @(posedge clk) \
      `RTL_ASSERT_NOT_X_MSG(net, msg)
	  
 `define RTL_ASSERT_NOT_X_NEGEDGE_MSG(clk, net, msg) \
    always @(negedge clk) \
      `RTL_ASSERT_NOT_X_MSG(net, msg)
	  
 `define RTL_ASSERT_NOT_X(net) \
    `RTL_ASSERT_NOT_X_MSG(net, "")
      
 `define RTL_ASSERT_NOT_X_ALWAYS(net) \
    `RTL_ASSERT_NOT_X_ALWAYS_MSG(net, "")
	
 `define RTL_ASSERT_NOT_X_POSEDGE(clk, net) \
    `RTL_ASSERT_NOT_X_POSEDGE_MSG(clk, net, "")
      
 `define RTL_ASSERT_NOT_X_NEGEDGE(clk, net) \
    `RTL_ASSERT_NOT_X_NEGEDGE_MSG(clk, net, "")

//-------------------------------------------------------------------
// One-hot macros
//-------------------------------------------------------------------

 `define RTL_IS_1HOT( net )         ( |net && (((net-1) & net) == 1'b0) )
  
 `define RTL_ASSERT_1HOT_MSG( net, msg ) \
    if ( `RTL_IS_1HOT( net ) ); \
    else `RTL_ERROR_1ARG( {"one hot assertion failed : ",msg}, net )

 `define RTL_ASSERT_1HOT_ALWAYS_MSG( net, msg ) \
    always @(*) \
      `RTL_ASSERT_1HOT_MSG( net, msg )

 `define RTL_ASSERT_1HOT_POSEDGE_MSG( clk, net, msg ) \
    always @( posedge clk ) \
      `RTL_ASSERT_1HOT_MSG( net, msg )

 `define RTL_ASSERT_1HOT_NEGEDGE_MSG( clk, net, msg ) \
    always @( negedge clk ) \
      `RTL_ASSERT_1HOT_MSG( net, msg )

 `define RTL_ASSERT_1HOT( net ) \
    if ( `RTL_IS_1HOT( net ) ); \
    else `RTL_ERROR_1ARG( {"one hot assertion failed"}, net )

 `define RTL_ASSERT_1HOT_ALWAYS( net ) \
    always @(*) \
      `RTL_ASSERT_1HOT_MSG( net, "" )

 `define RTL_ASSERT_1HOT_POSEDGE( clk, net ) \
    always @( posedge clk ) \
      `RTL_ASSERT_1HOT_MSG( net, "" )

 `define RTL_ASSERT_1HOT_NEGEDGE( clk, net ) \
    always @( negedge clk ) \
      `RTL_ASSERT_1HOT_MSG( net, "" )

//-------------------------------------------------------------------
// One-hot macros
//-------------------------------------------------------------------

 `define RTL_IS_1HOT_OR_ZERO( net ) ( ((net-1) & net) == 1'b0 )

 `define RTL_ASSERT_1HOT_OR_ZERO_MSG( net, msg ) \
    if ( `RTL_IS_1HOT_OR_ZERO( net ) ); \
    else `RTL_ERROR_1ARG( {"one hot or zero assertion failed : ",msg}, net )

 `define RTL_ASSERT_1HOT_OR_ZERO_ALWAYS_MSG( net, msg ) \
    always @(*) \
      `RTL_ASSERT_1HOT_OR_ZERO_MSG( net, msg )

 `define RTL_ASSERT_1HOT_OR_ZERO_POSEDGE_MSG( clk, net, msg ) \
    always @( posedge clk ) \
      `RTL_ASSERT_1HOT_OR_ZERO_MSG( net, msg )

 `define RTL_ASSERT_1HOT_OR_ZERO_NEGEDGE_MSG( clk, net, msg ) \
    always @( negedge clk ) \
      `RTL_ASSERT_1HOT_OR_ZERO_MSG( net, msg )

 `define RTL_ASSERT_1HOT_OR_ZERO( net ) \
    if ( `RTL_IS_1HOT_OR_ZERO( net ) ); \
    else `RTL_ERROR_1ARG( {"one hot or zero assertion failed"}, net )

 `define RTL_ASSERT_1HOT_OR_ZERO_ALWAYS( net ) \
    always @(*) \
      `RTL_ASSERT_1HOT_OR_ZERO_MSG( net, "" )

 `define RTL_ASSERT_1HOT_OR_ZERO_POSEDGE( clk, net ) \
    always @( posedge clk ) \
      `RTL_ASSERT_1HOT_OR_ZERO_MSG( net, "" )

 `define RTL_ASSERT_1HOT_OR_ZERO_NEGEDGE( clk, net ) \
    always @( negedge clk ) \
      `RTL_ASSERT_1HOT_OR_ZERO_MSG( net, "" )

//-------------------------------------------------------------------
// All 1s or All 0s
//-------------------------------------------------------------------

  `define RTL_IS_ALL_0( net, bits ) ( (|net === 1'bx) || (|net === 1'bz) || (net == {bits{1'b0}}) )
  `define RTL_IS_ALL_1( net, bits ) ( (|net === 1'bx) || (|net === 1'bz) || (net == {bits{1'b1}}) )

  `define RTL_ASSERT_ALL_0_OR_1_MSG( net, bits, msg ) \
    if ( `RTL_IS_ALL_0( net, bits ) || `RTL_IS_ALL_1( net, bits ) ); \
    else `RTL_ERROR_1ARG( {"all 0 or 1 assertion failed : ",msg}, net )

  `define RTL_ASSERT_ALL_0_OR_1_POSEDGE_MSG( clk, net, bits, msg ) \
    always @( posedge clk ) \
      `RTL_ASSERT_ALL_0_OR_1_MSG( net, bits, msg )
  
`endif //  `ifndef DEF_COMMON_V
