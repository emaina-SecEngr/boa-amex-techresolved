/**
 * Help Page — FAQ, Contact Info, User Guide
 * ConOps 6.8.4 — User Support
 */

import { useState } from "react";
import {
  HelpCircle,
  ChevronDown,
  ChevronRight,
  Mail,
  Phone,
  BookOpen,
  Shield,
  Calendar,
  Users,
  School as SchoolIcon,
} from "lucide-react";

const FAQ_SECTIONS = [
  {
    title: "Getting Started",
    icon: BookOpen,
    items: [
      {
        q: "How do I create an account?",
        a: "Click Register on the login page. Fill in your username, password, security questions, name, phone, email, and select your role (School Admin, Volunteer, or Admin). Your account will be pending until an LBB administrator approves it.",
      },
      {
        q: "Why is my account pending?",
        a: "For security, all new accounts must be approved by an LBB program administrator before you can access the system. You will receive an email once your account is approved.",
      },
      {
        q: "I forgot my password. What do I do?",
        a: "Click Forgot Password on the login page. You will be asked to verify your identity using your security questions, then you can set a new password.",
      },
      {
        q: "How do I update my profile information?",
        a: "After logging in, click on My Profile in the navigation menu. You can update your name, phone number, email, and affiliation.",
      },
    ],
  },
  {
    title: "For School Administrators",
    icon: SchoolIcon,
    items: [
      {
        q: "How do I register my school for an LBB event?",
        a: "Go to Register for Event in the navigation. Select the academic year, browse available dates, and click Register School on the date you want. Only one school can register per event date.",
      },
      {
        q: "Can I change my registered event date?",
        a: "Contact the LBB program administrator to make changes to your registration. They can reassign your school to a different available date.",
      },
      {
        q: "Where do I see my school schedule?",
        a: "Go to Our Schedule in the navigation to see all events your school is registered for, including dates, times, and confirmation status.",
      },
      {
        q: "How do I report photo restrictions for students?",
        a: "Photo restrictions are managed by the LBB administrator during school registration. Contact them with the list of students who have photo restrictions and which classes they will attend.",
      },
    ],
  },
  {
    title: "For Volunteers",
    icon: Users,
    items: [
      {
        q: "How do I sign up for an event?",
        a: "Go to Browse Events in the navigation. Select the academic year, find an available or reserved event, and click Sign Up. You can withdraw from an event at any time before it occurs.",
      },
      {
        q: "How do I create or update my volunteer profile?",
        a: "Go to My Classes in the navigation. If you do not have a profile yet, you will see a form to create one. You can add your organization, bio, and availability status.",
      },
      {
        q: "Will I receive reminders about upcoming events?",
        a: "Yes! The system automatically sends email reminders 14 days and 4 days before each event you are signed up for.",
      },
      {
        q: "How do I see which classes I am leading?",
        a: "Go to My Classes to see all life skills classes assigned to you, including class details, equipment needs, and student limits.",
      },
    ],
  },
  {
    title: "For LBB Administrators",
    icon: Shield,
    items: [
      {
        q: "How do I approve new user accounts?",
        a: "Go to Users in the admin navigation. Pending accounts appear at the top. Click Approve to activate the account or Deny to reject it.",
      },
      {
        q: "How do I create event dates for the academic year?",
        a: "Go to Events, select or create an academic year, then add available event dates. Schools and volunteers can then register for these dates.",
      },
      {
        q: "How do I record a donation?",
        a: "Go to Donations and click Add Donation. Enter the donor information, amount, date, type (cash or in-kind), and whether a thank-you letter has been sent.",
      },
      {
        q: "How do I generate reports?",
        a: "Go to Reports to access the analytics dashboard. You can view Events Summary and Volunteer Engagement reports with interactive charts, and download them as CSV or PDF.",
      },
      {
        q: "How do I manage surveys?",
        a: "Go to Surveys to create and manage volunteer, student, and school surveys. You can view responses and track completion rates.",
      },
    ],
  },
  {
    title: "Technical Support",
    icon: HelpCircle,
    items: [
      {
        q: "What browsers are supported?",
        a: "LBBS works on all modern browsers including Chrome, Firefox, Safari, and Edge. We recommend using the latest version for the best experience.",
      },
      {
        q: "Can I access LBBS on my phone or tablet?",
        a: "Yes! LBBS is fully responsive and works on phones, tablets, and desktop computers.",
      },
      {
        q: "Who do I contact for technical issues?",
        a: "Email the LBB IT Support team at support@lifebeyondthebooksaz.org or call (520) 555-0199 during business hours (Mon-Fri, 8 AM - 5 PM MST).",
      },
      {
        q: "Is my data secure?",
        a: "Yes. LBBS uses industry-standard security including encrypted passwords, JWT authentication, multi-factor authentication for admins, role-based access control, and FERPA-compliant data handling.",
      },
    ],
  },
];

export default function HelpPage() {
  const [openSection, setOpenSection] = useState(0);
  const [openItem, setOpenItem] = useState(null);

  const toggleSection = (idx) => {
    setOpenSection(openSection === idx ? null : idx);
    setOpenItem(null);
  };

  const toggleItem = (key) => {
    setOpenItem(openItem === key ? null : key);
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 flex items-center space-x-2">
          <HelpCircle size={28} />
          <span>Help and Support</span>
        </h1>
        <p className="text-gray-500 mt-1">
          Frequently asked questions and support resources for LBBS
        </p>
      </div>

      {/* Quick Links */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <QuickLink icon={Calendar} label="Events Guide" section={1} onClick={() => toggleSection(1)} />
        <QuickLink icon={Users} label="Volunteer Guide" section={2} onClick={() => toggleSection(2)} />
        <QuickLink icon={SchoolIcon} label="School Guide" section={1} onClick={() => toggleSection(1)} />
        <QuickLink icon={Mail} label="Contact Support" section={4} onClick={() => toggleSection(4)} />
      </div>

      {/* FAQ Sections */}
      <div className="space-y-3">
        {FAQ_SECTIONS.map((section, sIdx) => (
          <div key={sIdx} className="card overflow-hidden">
            <button
              onClick={() => toggleSection(sIdx)}
              className="w-full flex items-center justify-between p-1 hover:bg-gray-50 rounded-lg transition"
            >
              <div className="flex items-center space-x-3">
                <div className="p-2 bg-blue-50 text-blue-700 rounded-lg">
                  <section.icon size={20} />
                </div>
                <h2 className="font-semibold text-gray-900">{section.title}</h2>
                <span className="text-xs text-gray-400 bg-gray-100 px-2 py-0.5 rounded-full">
                  {section.items.length} questions
                </span>
              </div>
              {openSection === sIdx ? <ChevronDown size={20} className="text-gray-400" /> : <ChevronRight size={20} className="text-gray-400" />}
            </button>

            {openSection === sIdx && (
              <div className="mt-3 space-y-2">
                {section.items.map((item, iIdx) => {
                  const key = `${sIdx}-${iIdx}`;
                  return (
                    <div key={key} className="border border-gray-100 rounded-lg">
                      <button
                        onClick={() => toggleItem(key)}
                        className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-gray-50 transition"
                      >
                        <span className="text-sm font-medium text-gray-800">{item.q}</span>
                        {openItem === key ? <ChevronDown size={16} className="text-gray-400 flex-shrink-0" /> : <ChevronRight size={16} className="text-gray-400 flex-shrink-0" />}
                      </button>
                      {openItem === key && (
                        <div className="px-4 pb-3">
                          <p className="text-sm text-gray-600 leading-relaxed">{item.a}</p>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Contact Section */}
      <div className="card bg-blue-50 border border-blue-200">
        <h2 className="font-semibold text-blue-900 mb-3 flex items-center space-x-2">
          <Mail size={20} />
          <span>Contact Support</span>
        </h2>
        <div className="grid md:grid-cols-2 gap-4 text-sm">
          <div className="flex items-start space-x-3">
            <Mail size={18} className="text-blue-600 mt-0.5" />
            <div>
              <p className="font-medium text-blue-900">Email Support</p>
              <p className="text-blue-700">support@lifebeyondthebooksaz.org</p>
              <p className="text-blue-500 text-xs mt-1">Response within 24 hours</p>
            </div>
          </div>
          <div className="flex items-start space-x-3">
            <Phone size={18} className="text-blue-600 mt-0.5" />
            <div>
              <p className="font-medium text-blue-900">Phone Support</p>
              <p className="text-blue-700">(520) 555-0199</p>
              <p className="text-blue-500 text-xs mt-1">Mon-Fri, 8 AM - 5 PM MST</p>
            </div>
          </div>
        </div>
      </div>

      {/* About Section */}
      <div className="card">
        <h2 className="font-semibold text-gray-900 mb-2">About LBBS</h2>
        <p className="text-sm text-gray-600 leading-relaxed">
          The Life Beyond the Books Scheduler (LBBS) is a scheduling and management platform
          for the Life Beyond the Books program. LBB partners community professionals with
          8th grade students to bring essential life skills to life in the classroom. LBBS helps
          coordinate schools, volunteers, events, and program administration for the Amphitheater
          and Flowing Wells School Districts in Tucson, Arizona.
        </p>
        <p className="text-xs text-gray-400 mt-3">
          LBBS v1.0.0 | SFWE 402 DevSecOps Capstone | University of Arizona
        </p>
      </div>
    </div>
  );
}

function QuickLink({ icon: Icon, label, onClick }) {
  return (
    <button
      onClick={onClick}
      className="card flex flex-col items-center py-4 hover:shadow-md transition cursor-pointer"
    >
      <Icon size={24} className="text-blue-600 mb-2" />
      <span className="text-xs font-medium text-gray-700">{label}</span>
    </button>
  );
}
