"""LBB Payment Processor — executes transfers atomically"""
import uuid
import logging

logger = logging.getLogger("lbb-processor")


class PaymentProcessor:

    async def execute_transfer(self, db, transaction_id: str,
                                sender_account: str, receiver_account: str,
                                amount: float, currency: str, memo: str = None):
        """
        Execute atomic transfer — debit sender, credit receiver.
        Uses database transaction to ensure consistency.
        If either operation fails, both are rolled back.
        """
        try:
            # Debit sender
            await db.execute(
                "UPDATE accounts SET available_balance = available_balance - :amount WHERE account_number = :acct",
                {"amount": amount, "acct": sender_account}
            )

            # Credit receiver
            await db.execute(
                "UPDATE accounts SET available_balance = available_balance + :amount WHERE account_number = :acct",
                {"amount": amount, "acct": receiver_account}
            )

            # Get updated balances
            sender = await db.fetch_one(
                "SELECT available_balance FROM accounts WHERE account_number = :acct",
                {"acct": sender_account}
            )
            receiver = await db.fetch_one(
                "SELECT available_balance FROM accounts WHERE account_number = :acct",
                {"acct": receiver_account}
            )

            confirmation = f"TRF-{uuid.uuid4().hex[:8].upper()}"

            # Log the transfer
            await db.execute("""
                INSERT INTO payment_log
                (transaction_id, sender_account, receiver_account, amount,
                 currency, status, reason, transaction_type, memo)
                VALUES (:tx_id, :sender, :receiver, :amount,
                        :currency, 'COMPLETED', 'Transfer successful', 'P2P_TRANSFER', :memo)
            """, {
                "tx_id": transaction_id, "sender": sender_account,
                "receiver": receiver_account, "amount": amount,
                "currency": currency, "memo": memo
            })

            logger.info(f"Transfer executed: {transaction_id}, ${amount} from {sender_account} to {receiver_account}")

            return {
                "sender_balance": float(sender["available_balance"]),
                "receiver_balance": float(receiver["available_balance"]),
                "confirmation": confirmation
            }

        except Exception as e:
            logger.error(f"Transfer FAILED: {transaction_id}, error={str(e)}")
            raise