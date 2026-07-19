/**
 * LBB Banking Portal — React Frontend
 * Customer-facing banking application
 * 
 * Features: Account dashboard, transfers, statements, profile
 * Auth: AWS Cognito + JWT
 * CDN: CloudFront → S3
 */
import React, { useState, useEffect } from 'react';

function App() {
  const [accounts, setAccounts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/v1/accounts', {
      headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` }
    })
      .then(res => res.json())
      .then(data => { setAccounts(data.accounts || []); setLoading(false); })
      .catch(() => setLoading(false));
  }, []);

  if (loading) return <div className="p-8 text-center">Loading accounts...</div>;

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-blue-900 text-white p-4">
        <h1 className="text-2xl font-bold">LBB Banking Portal</h1>
        <p className="text-blue-200">BOA-AMEX-TechResolved</p>
      </header>
      <main className="max-w-4xl mx-auto p-6">
        <h2 className="text-xl font-semibold mb-4">Your Accounts</h2>
        {accounts.map(acct => (
          <div key={acct.account_number} className="bg-white rounded-lg shadow p-4 mb-4">
            <div className="flex justify-between items-center">
              <div>
                <p className="font-medium">{acct.account_type}</p>
                <p className="text-gray-500 text-sm">{acct.account_number}</p>
              </div>
              <p className="text-2xl font-bold">${acct.available_balance?.toFixed(2)}</p>
            </div>
          </div>
        ))}
      </main>
    </div>
  );
}

export default App;
