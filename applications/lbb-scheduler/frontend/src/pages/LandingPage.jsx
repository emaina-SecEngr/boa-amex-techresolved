/**
 * Landing Page — Public Home Page
 * ==================================
 * The first page visitors see. Explains the LBB program
 * and provides entry points for different user types.
 */

import { Link } from "react-router-dom";
import { Calendar, Users, School, BarChart3 } from "lucide-react";

export default function LandingPage() {
  // Define features as data, then render them with .map()
  // Same pattern we used in the Navbar
  const features = [
    {
      icon: Calendar,
      title: "Event Scheduling",
      description:
        "Schools register for LBB events and volunteers sign up to teach life skills classes.",
    },
    {
      icon: Users,
      title: "Volunteer Management",
      description:
        "Professionals create profiles, manage their schedules, and track their contributions.",
    },
    {
      icon: School,
      title: "School Coordination",
      description:
        "School administrators register for events, manage logistics, and track student participation.",
    },
    {
      icon: BarChart3,
      title: "Reports & Analytics",
      description:
        "Program administrators generate reports, track metrics, and manage the program budget.",
    },
  ];

  return (
    <div className="max-w-5xl mx-auto">
      {/* Hero Section */}
      <div className="text-center py-16">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">
          Life Beyond the Books
        </h1>
        <p className="text-xl text-gray-600 mb-2">Scheduler</p>
        <p className="text-lg text-gray-500 max-w-2xl mx-auto mb-8">
          Preparing students for life through teaching the life skills needed to
          run a home and prepare for a career.
        </p>
        <div className="flex justify-center space-x-4">
          <Link to="/register" className="btn-primary text-lg px-8 py-3">
            Get Started
          </Link>
          <Link to="/login" className="btn-secondary text-lg px-8 py-3">
            Login
          </Link>
        </div>
      </div>

      {/* Features Grid */}
      <div className="grid md:grid-cols-2 gap-6 pb-16">
        {features.map((feature) => {
          const Icon = feature.icon;
          return (
            <div key={feature.title} className="card">
              <div className="flex items-start space-x-4">
                <div className="bg-blue-50 p-3 rounded-lg">
                  <Icon className="text-lbb-primary" size={24} />
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900 mb-1">
                    {feature.title}
                  </h3>
                  <p className="text-gray-600 text-sm">{feature.description}</p>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Mission Statement */}
      <div className="text-center py-12 border-t border-gray-200">
        <p className="text-gray-500 italic">
          &ldquo;All students are self-sufficient and ready for life.&rdquo;
        </p>
        <p className="text-sm text-gray-400 mt-2">
          Serving middle schools in the Amphitheater and Flowing Wells School
          Districts, Tucson, Arizona
        </p>
      </div>
    </div>
  );
}

