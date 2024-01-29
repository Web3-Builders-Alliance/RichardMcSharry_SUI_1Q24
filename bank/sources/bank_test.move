#[test_only]
module bank::bank_tests {
    use sui::test_utils::assert_eq;
    use sui::coin::{mint_for_testing, burn_for_testing};
    use sui::test_scenario as ts;
    use sui::coin::{Self};

    use bank::bank::{Self, Bank, OwnerCap};

    // these hex values can be anything, but they must be unique (don't have to be a full unique addres like on-chain)
    const ADMIN: address = @0xBEEF;
    const ALICE: address =  @0x1337;

    fun calculate_fee_helper(deposit_amount:u64) : (u64, u64) {
      // the balance for a coin is always u64, but we need to do our math casting up to u128 to avoid exceptions in our math, then cast back down to u64
      let admin_amount = bank::fee_calculator_for_testing(deposit_amount);
      let actual_user_amount = deposit_amount - admin_amount;
      
      (actual_user_amount, admin_amount)
    }

    // helper for initializing the bank, and returns the scenario_val
    fun init_test_helper() : ts::Scenario {
      let scenario_val = ts::begin(ADMIN);
      let scenario = &mut scenario_val;
      {
        bank::init_for_testing(ts::ctx(scenario));
      };
      scenario_val
    }

    fun deposit_test_helper(scenario: &mut ts::Scenario, addr:address, amount:u64) {
      ts::next_tx(scenario, addr);
      {
        let bank = ts::take_shared<Bank>(scenario);
        let mint_deposit = mint_for_testing(amount, ts::ctx(scenario));
        bank::deposit(&mut bank, mint_deposit, ts::ctx(scenario));

        let (user_amount, admin_amount) = calculate_fee_helper(amount);

        assert_eq(bank::user_balance(&mut bank, addr), user_amount);
        assert_eq(bank::admin_balance(&mut bank), admin_amount);

        ts::return_shared(bank);
      };
    }

    fun withdraw_test_helper(scenario: &mut ts::Scenario, addr:address, expected_amount:u64) {
      ts::next_tx(scenario, addr);
      {
        let bank = ts::take_shared<Bank>(scenario);
        let withdrawal = bank::withdraw(&mut bank, ts::ctx(scenario)); // note we are withdrawing the full amount

        assert_eq(bank::user_balance(&mut bank, addr), 0);
        assert_eq(coin::value(&withdrawal), expected_amount);

        burn_for_testing(withdrawal);
        ts::return_shared(bank);
      };
    }

    fun claim_test_helper(scenario: &mut ts::Scenario, addr:address, expected_fees:u64) {
      ts::next_tx(scenario, addr);
      {
        let owner_cap = ts::take_from_sender<OwnerCap>(scenario); // get the owner capability for the bank

        let bank = ts::take_shared<Bank>(scenario);
        let claimed_fees = bank::claim(&owner_cap, &mut bank, ts::ctx(scenario));

        assert_eq(bank::admin_balance(&mut bank), 0);
        assert_eq(coin::value(&claimed_fees), expected_fees);

        burn_for_testing(claimed_fees);
        ts::return_to_sender(scenario, owner_cap);
        ts::return_shared(bank);
      };
    }

    #[test]
    fun test_deposit() {
      let scenario_val = init_test_helper();
      let scenario = &mut scenario_val;

      deposit_test_helper(scenario, ALICE, 100);

      ts::end(scenario_val);
    }

    #[test]
    fun test_withdraw() {
      let scenario_val = init_test_helper();
      let scenario = &mut scenario_val;    

      // we deposit 100, but the user only gets 95 (as the admin gets 5) so we expect 95 back
      deposit_test_helper(scenario, ALICE, 100);
      withdraw_test_helper(scenario, ALICE, 95);

      ts::end(scenario_val);
    }

    #[test]
    fun test_withdraw_empty_balance() {
      let scenario_val = init_test_helper();
      let scenario = &mut scenario_val;    

      // no deposit made, so withdraw should return 0 balance
      withdraw_test_helper(scenario, ALICE, 0);

      ts::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    // withdrawing without having deposited anything should fail!
    fun test_withdraw_fail_no_deposit_made() {
      let scenario_val = init_test_helper();
      let scenario = &mut scenario_val; 

      withdraw_test_helper(scenario, ALICE, 95);

      ts::end(scenario_val);
    }

    // claim test, which is the admin/owner of the bank claiming the fees
    #[test]
    fun test_claim() {
      let scenario_val = init_test_helper();
      let scenario = &mut scenario_val;    

      deposit_test_helper(scenario, ALICE, 100);
      claim_test_helper(scenario, ADMIN, 5); // admin claims the fees, which should be 5

      ts::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    // test that a user cannot claim the banks fees
    fun test_user_claim_fail() {
      let scenario_val = init_test_helper();
      let scenario = &mut scenario_val;

      deposit_test_helper(scenario, ALICE, 100);
      claim_test_helper(scenario, ALICE, 5);

      ts::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    // claiming where no deposits have been made should fail!
    fun test_claim_fail() {
      let scenario_val = init_test_helper();
      let scenario = &mut scenario_val; 

      // note there is no deposit first, and admin is expecting to claim fees amount of 5 (which should fail)
      claim_test_helper(scenario, ADMIN, 5);

      ts::end(scenario_val);     
    }
}
