/**
 * 404 Not Found Page
 * ====================
 * Shown when a user visits a URL that doesn't match any route.
 * Provides a friendly message and a link back to the home page.
 */

import { Link } from "react-router-dom";

export default function NotFoundPage() {
  return (
    <div className="text-center py-24">
      <h1 className="text-6xl font-bold text-gray-300 mb-4">404</h1>
      <h2 className="text-2xl font-semibold text-gray-800 mb-2">
        Page Not Found
      </h2>
      <p className="text-gray-500 mb-8">
        The page you&apos;re looking for doesn&apos;t exist or has been moved.
      </p>
      <Link to="/" className="btn-primary">
        Go Home
      </Link>
    </div>
  );
}

