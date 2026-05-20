import React, { useState } from 'react';
import { Calendar, Shield, Award, MapPin, DollarSign, ChevronRight, ArrowLeft, PhilippinePeso } from 'lucide-react';
import Utility from './Utility';
import PostModeration from './PostModeration';
import Certificates from './Certificates';
import StationActivity from './StationActivity';
import PricingUtility from './PricingUtility';
import '../style/UtilityCenter.css';

const MODULES = [
  {
    id: 'calendar',
    title: 'Calendar Configuration',
    category: 'Booking Control',
    description:
      'Manage buffer dates, closed dates, events, and daily trekker capacity slots for the trek booking calendar.',
    Icon: Calendar,
    iconBg: '#eaf5e7',
    iconColor: '#2d6b22',
  },
  {
    id: 'pricing',
    title: 'Pricing Configuration',
    category: 'Booking Control',
    description:
      'Set base trek fees, per-category discounts, service prices (porter, guide, scientist), and off-season rules. Changes sync instantly to the mobile app.',
    Icon: PhilippinePeso,
    iconBg: '#f0fdf4',
    iconColor: '#15803d',
  },
  {
    id: 'moderation',
    title: 'Post Moderation',
    category: 'Content Review',
    description:
      'Review, approve, or decline community posts submitted by trekkers before they appear in the public social feed.',
    Icon: Shield,
    iconBg: '#fef3c7',
    iconColor: '#d97706',
  },
  {
    id: 'certificates',
    title: 'Certificates',
    category: 'Documentation',
    description:
      'Generate and manage trek completion certificates for trekkers who have successfully completed their Mt. Hamiguitan journey.',
    Icon: Award,
    iconBg: '#eff6ff',
    iconColor: '#2563eb',
  },
  {
    id: 'stations',
    title: 'Station Activity',
    category: 'Monitoring',
    description:
      'Monitor real-time check-in and check-out activity at trek stations to track trekker progress and ensure trail safety.',
    Icon: MapPin,
    iconBg: '#fdf4ff',
    iconColor: '#9333ea',
  },
];

function UtilityCenter({ adminName }) {
  const [activeModule, setActiveModule] = useState(null);

  if (activeModule) {
    const mod = MODULES.find((m) => m.id === activeModule);
    return (
      <div className="uc-module-view">
        <div className="uc-module-nav">
          <button className="uc-back-btn" onClick={() => setActiveModule(null)}>
            <ArrowLeft size={15} />
            Utility Center
          </button>
          <span className="uc-nav-sep">
            <ChevronRight size={14} />
          </span>
          <span className="uc-nav-label">{mod?.title}</span>
        </div>

        {activeModule === 'calendar'     && <Utility />}
        {activeModule === 'pricing'      && <PricingUtility />}
        {activeModule === 'moderation'   && <PostModeration adminName={adminName} />}
        {activeModule === 'certificates' && <Certificates adminName={adminName} />}
        {activeModule === 'stations'     && <StationActivity />}
      </div>
    );
  }

  return (
    <div>
      <div className="uc-hub-header">
        <div className="uc-breadcrumb">
          <span className="uc-breadcrumb-root">Admin</span>
          <ChevronRight size={13} className="uc-breadcrumb-sep" />
          <span className="uc-breadcrumb-current">Utility Center</span>
        </div>
        <h1 className="uc-hub-title">Utility Center</h1>
        <p className="uc-hub-desc">
          Advanced administrative controls for Mount Hamiguitan World Heritage site — manage booking calendars, moderate community content, issue certifications, and monitor trail stations.
        </p>
      </div>

      <div className="uc-grid">
        {MODULES.map(({ id, title, category, description, Icon, iconBg, iconColor }) => (
          <button key={id} className="uc-card" onClick={() => setActiveModule(id)}>
            <div className="uc-card-top">
              <div className="uc-card-icon" style={{ background: iconBg, color: iconColor }}>
                <Icon size={22} />
              </div>
              <span className="uc-card-category">{category}</span>
            </div>
            <h3 className="uc-card-title">{title}</h3>
            <p className="uc-card-desc">{description}</p>
            <span className="uc-card-cta">
              Open Module <ChevronRight size={14} />
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

export default UtilityCenter;
