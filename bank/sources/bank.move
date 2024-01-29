module bank::bank {
  use sui::transfer;
  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};
  use sui::coin::{Self, Coin};
  use sui::sui::SUI;
  use sui::dynamic_field as df;
  use sui::balance::{Self, Balance};

  struct Bank has key {
    id: UID
  }

  struct OwnerCap has key, store {
    id: UID
  }

  struct UserBalance has copy, drop, store { user: address }
  struct AdminBalance has copy, drop, store {}

  // bank fee for each deposit (5% in this case)
  const FEE_PERCENT: u8 = 5;

  fun init(ctx: &mut TxContext) {  
    let new_bank = Bank { id: object::new(ctx) };
    df::add(&mut new_bank.id, AdminBalance{}, balance::zero<SUI>());

    transfer::share_object(new_bank);

    transfer::transfer(OwnerCap{ id: object::new(ctx)}, tx_context::sender(ctx));
  }

  // helper to calculate the fee amount from the deposit value and the fee percent
  fun fee_calculator(value: u64): u64 {
    // To avoid overflows, we cast the value to u128 when multiplying then cast it back to u64
    (((value as u128) * (FEE_PERCENT as u128) / 100) as u64)
  }

  /// Below is the function defitinon for adding a dynamic field to the object `object: &mut UID` at field specified by `name: Name`.
  /// Aborts with `EFieldAlreadyExists` if the object already has that field with that name.
  // public fun add<Name: copy + drop + store, Value: store>(
  //   object: &mut UID,
  //   name: Name,
  //   value: Value,
  // )

  public fun deposit(self: &mut Bank, token: Coin<SUI>, ctx: &mut TxContext) {

    // since the token is an object, we need to extract the actual "monetary" value from it
    let value = coin::value(&token);

    let admin_fee_amount = fee_calculator(value);

    // NOTE this is how you could get the deposit amount (ie. the user part of the token balance)
    // let deposit_amount = coin::value(&token) - admin_fee_amount;

    // Get the existing admin balance from the bank (see init function for how this was created)
    let bank_balance = df::borrow_mut<AdminBalance, Balance<SUI>>(
      &mut self.id,
      AdminBalance {},
    );

    // now split off the admin fee as a coin from the token, which will leave the token with just the user part of the token balance
    let admin_coin = coin::split(&mut token, admin_fee_amount, ctx);

    // add the admin_fee coin to the admin current balance
    let admin_fee = coin::into_balance(admin_coin);
    balance::join(bank_balance, admin_fee);

    // FINALLY WE HANDLE THE USER DEPOSIT
    // first check if the user already has a balance (ie. a bank account) and if so, join the existing balance
    // else, create a new balance for the user (note we already split the token, so the token is now just the user part of the balance)
    if (df::exists_(&self.id, UserBalance { user: tx_context::sender(ctx) })) {
      balance::join(df::borrow_mut<UserBalance, Balance<SUI>>(&mut self.id, UserBalance { user: tx_context::sender(ctx) }),
      coin::into_balance(token));
    } else {
      // since the user does not exist, we use the df add function to add a new balance to the bank for this user
      df::add(&mut self.id, UserBalance { user: tx_context::sender(ctx) }, coin::into_balance(token));
    };
  }

  public fun withdraw(self: &mut Bank, ctx: &mut TxContext): Coin<SUI> {
    let sender = tx_context::sender(ctx);

    // first check if the user already has a balance, and if so then withdraw the full balance amount
    // else, return zero balance
    if (df::exists_(&self.id, UserBalance { user: sender })) {
      coin::from_balance(df::remove(&mut self.id, UserBalance { user: sender }), ctx)
    } else {
      coin::zero(ctx)
    }
  }

  public fun claim(_: &OwnerCap, self: &mut Bank, ctx: &mut TxContext): Coin<SUI> {
    coin::from_balance(df::remove(&mut self.id, AdminBalance {}), ctx)
  }

  public fun user_balance(self: &mut Bank, user: address): u64 {
    if (df::exists_(&self.id, UserBalance { user: user })) {
      balance::value(df::borrow_mut<UserBalance, Balance<SUI>>(&mut self.id, UserBalance { user: user }))
    } else {
      0
    }
  }

  public fun admin_balance(self: &mut Bank): u64 {
    if (df::exists_(&self.id, AdminBalance {})) {
      balance::value(df::borrow_mut<AdminBalance, Balance<SUI>>(&mut self.id, AdminBalance {}))
    } else {
      0
    }
  }

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx)
  }

  #[test_only]
  public fun fee_calculator_for_testing(value: u64): u64 {
    fee_calculator(value)
  }
}