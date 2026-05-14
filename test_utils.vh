// Shared testbench utilities.
// `include inside a testbench module after defining: localparam TB_NAME = "...";

integer fail_count = 0;

task pass_fail;
  input      ok;
  input [8*48-1:0] name;
  begin
    if (ok) $display("  PASS: %0s", name);
    else begin
      $display("  FAIL: %0s", name);
      fail_count = fail_count + 1;
    end
  end
endtask

task finish_test;
  begin
    $display("==========================");
    if (fail_count == 0)
      $display("ALL TESTS PASSED");
    else
      $display("%0d TEST(S) FAILED", fail_count);
    $display("==========================");
    $finish;
  end
endtask
