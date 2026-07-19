-- LBBS Demo Seed v2 — matches actual schema
DELETE FROM volunteer_event_signups;
DELETE FROM event_registrations;
DELETE FROM school_surveys;
DELETE FROM student_surveys;
DELETE FROM volunteer_surveys;
DELETE FROM donations;
DELETE FROM life_skills_classes;
DELETE FROM volunteer_profiles;
DELETE FROM school_principals;
DELETE FROM photo_restrictions;
DELETE FROM lbb_events;
DELETE FROM schools;
DELETE FROM academic_years;
DELETE FROM users;

-- 1. USERS (password: Password123!)
INSERT INTO users (id, username, password_hash, security_question_1, security_answer_1, security_question_2, security_answer_2, first_name, last_name, phone_number, email, role, is_active, affiliation, created_at, updated_at) VALUES
('a0000001-0000-0000-0000-000000000001','admin','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','tucson','What is your pet name?','buddy','Michael','Johnson','520-555-0101','admin@lbbs.org','lbb_admin',true,'LBB Organization',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000002','sarah_admin','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','phoenix','What is your pet name?','max','Sarah','Williams','520-555-0102','sarah@lbbs.org','lbb_admin',true,'LBB Organization',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000003','it_mike','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','flagstaff','What is your pet name?','luna','Mike','Chen','520-555-0103','mike.chen@lbbs.org','it_support',true,'LBB IT',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000010','kirk','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','tucson','What is your pet name?','rex','Kirk','Douglas','520-555-0110','kirk@volunteer.org','volunteer',true,'Tucson Community Bank',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000011','maria_v','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','mesa','What is your pet name?','bella','Maria','Garcia','520-555-0111','maria@volunteer.org','volunteer',true,'Arizona Financial Group',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000012','james_v','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','tempe','What is your pet name?','duke','James','Thompson','520-555-0112','james@volunteer.org','volunteer',true,'Raytheon Tucson',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000013','lisa_v','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','tucson','What is your pet name?','coco','Lisa','Martinez','520-555-0113','lisa@volunteer.org','volunteer',true,'University of Arizona',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000014','robert_v','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','chandler','What is your pet name?','rocky','Robert','Anderson','520-555-0114','robert@volunteer.org','volunteer',true,'Tucson Electric Power',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000015','jennifer_v','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','scottsdale','What is your pet name?','daisy','Jennifer','Wilson','520-555-0115','jennifer@volunteer.org','volunteer',true,'Banner Health',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000020','amphi_admin','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','tucson','What is your pet name?','spot','Patricia','Brown','520-555-0120','pbrown@amphi.com','school_admin',true,'Amphitheater School District',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000021','flowing_admin','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','tucson','What is your pet name?','charlie','David','Lee','520-555-0121','dlee@flowingwells.org','school_admin',true,'Flowing Wells School District',NOW(),NOW()),
('a0000001-0000-0000-0000-000000000022','pending_user','$2b$12$LJ3m4ys3Lk0TSwMCfVCZPO8/RFPo4WKBF6K4GqkJMF9XkFQ9YGKK','What city were you born in?','tucson','What is your pet name?','ollie','Tom','Pending','520-555-0122','tom@pending.org','volunteer',false,'Pending Corp',NOW(),NOW());

-- 2. ACADEMIC YEARS
INSERT INTO academic_years (id, name, start_date, end_date, is_active) VALUES
('b0000001-0000-0000-0000-000000000001','2025-2026','2025-08-01','2026-06-30',true),
('b0000001-0000-0000-0000-000000000002','2026-2027','2026-08-01','2027-06-30',true);

-- 3. SCHOOLS
INSERT INTO schools (id, school_name, school_district, school_address, poc_name, poc_phone, poc_email, comments, admin_user_id, created_at, updated_at) VALUES
('c0000001-0000-0000-0000-000000000001','Amphi Middle School','Amphitheater','315 E Prince Rd, Tucson AZ 85705','Patricia Brown','520-555-0201','pbrown@amphi.com','Main campus',  'a0000001-0000-0000-0000-000000000020',NOW(),NOW()),
('c0000001-0000-0000-0000-000000000002','Cross Middle School','Amphitheater','1000 W Chapala Dr, Tucson AZ 85704','Nancy Clark','520-555-0202','nclark@amphi.com',NULL,NULL,NOW(),NOW()),
('c0000001-0000-0000-0000-000000000003','La Cima Middle School','Amphitheater','5757 N La Cima Dr, Tucson AZ 85718','Susan Hall','520-555-0203','shall@amphi.com',NULL,NULL,NOW(),NOW()),
('c0000001-0000-0000-0000-000000000004','Flowing Wells Jr High','Flowing Wells','3725 N Flowing Wells Rd, Tucson AZ 85705','David Lee','520-555-0204','dlee@flowingwells.org','Largest campus','a0000001-0000-0000-0000-000000000021',NOW(),NOW()),
('c0000001-0000-0000-0000-000000000005','Homer Davis Elementary','Flowing Wells','5765 N Shannon Rd, Tucson AZ 85741','Karen White','520-555-0205','kwhite@flowingwells.org',NULL,NULL,NOW(),NOW());

-- 4. SCHOOL PRINCIPALS
INSERT INTO school_principals (id, school_id, name, title) VALUES
(gen_random_uuid(),'c0000001-0000-0000-0000-000000000001','Dr. Rebecca Torres','Principal'),
(gen_random_uuid(),'c0000001-0000-0000-0000-000000000002','Mr. John Stevens','Principal'),
(gen_random_uuid(),'c0000001-0000-0000-0000-000000000003','Ms. Angela Price','Principal'),
(gen_random_uuid(),'c0000001-0000-0000-0000-000000000004','Dr. Michael Rivera','Principal'),
(gen_random_uuid(),'c0000001-0000-0000-0000-000000000005','Mrs. Linda Foster','Principal');

-- 5. PHOTO RESTRICTIONS
INSERT INTO photo_restrictions (id, school_id, student_name, class_assignment, academic_year_id) VALUES
(gen_random_uuid(),'c0000001-0000-0000-0000-000000000001','Student A','Period 3','b0000001-0000-0000-0000-000000000001'),
(gen_random_uuid(),'c0000001-0000-0000-0000-000000000001','Student B','Period 5','b0000001-0000-0000-0000-000000000001'),
(gen_random_uuid(),'c0000001-0000-0000-0000-000000000004','Student C','Period 2','b0000001-0000-0000-0000-000000000001');

-- 6. LIFE SKILLS CLASSES
INSERT INTO life_skills_classes (id, class_name, lead_volunteer_id, description, other_volunteers, special_logistics, equipment_by_professional, equipment_by_lbb, max_students, recommended_take_home_item, volunteer_take_home_item, created_at, updated_at) VALUES
('d0000001-0000-0000-0000-000000000001','Financial Literacy','a0000001-0000-0000-0000-000000000010','Budgeting, saving, and basic investing for teens','2 assistants needed','Need projector and whiteboard','Calculators, sample budgets','Worksheets, pencils',25,'Budget planner workbook','Thank you card',NOW(),NOW()),
('d0000001-0000-0000-0000-000000000002','Resume Writing','a0000001-0000-0000-0000-000000000011','How to create a professional resume and cover letter','1 assistant','Computer lab access needed','Laptops, sample resumes','Printer paper, folders',20,'Resume template USB drive','Gift card',NOW(),NOW()),
('d0000001-0000-0000-0000-000000000003','First Aid & Safety','a0000001-0000-0000-0000-000000000012','Basic first aid, CPR awareness, and home safety','2 assistants','Large open space needed','First aid kits, mannequin','Bandages, gloves',25,'Mini first aid kit','Certificate',NOW(),NOW()),
('d0000001-0000-0000-0000-000000000004','Cooking Basics','a0000001-0000-0000-0000-000000000013','Nutrition, meal planning, and simple recipes','3 assistants','Kitchen or portable cooking station','Portable stove, utensils','Ingredients, napkins',20,'Recipe card set','Apron',NOW(),NOW()),
('d0000001-0000-0000-0000-000000000005','Auto Maintenance','a0000001-0000-0000-0000-000000000014','Basic car care: oil, tires, jumpstart, maintenance','1 assistant','Outdoor area or garage','Car parts display, tools','Rags, safety glasses',15,'Car maintenance checklist','Keychain flashlight',NOW(),NOW()),
('d0000001-0000-0000-0000-000000000006','Interview Skills','a0000001-0000-0000-0000-000000000015','Professional communication, body language, mock interviews','2 assistants','Quiet room for mock interviews','Video camera, question cards','Notepads, pens',20,'Professional tips booklet','Pen set',NOW(),NOW());

-- 7. VOLUNTEER PROFILES
INSERT INTO volunteer_profiles (id, user_id, organization, bio, special_requirements, is_available, background_check_status, created_at, updated_at) VALUES
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000010','Tucson Community Bank','Banking professional with 15 years in consumer finance',NULL,true,'cleared',NOW(),NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000011','Arizona Financial Group','HR Director passionate about career prep for youth',NULL,true,'cleared',NOW(),NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000012','Raytheon Tucson','Former EMT and Red Cross certified safety trainer',NULL,true,'cleared',NOW(),NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000013','University of Arizona','Nutrition scientist and cooking enthusiast',NULL,true,'cleared',NOW(),NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000014','Tucson Electric Power','Automotive technician for 20 years','Needs parking for truck with display',true,'cleared',NOW(),NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000015','Banner Health','Corporate recruiter with 1000+ interviews conducted',NULL,true,'pending',NOW(),NOW());

-- 8. EVENTS
INSERT INTO lbb_events (id, academic_year_id, event_date, event_time, status, notes, created_at) VALUES
('e0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001','2025-10-15','09:00:00','completed','Fall semester kickoff',NOW()),
('e0000001-0000-0000-0000-000000000002','b0000001-0000-0000-0000-000000000001','2025-11-12','10:00:00','completed','November session',NOW()),
('e0000001-0000-0000-0000-000000000003','b0000001-0000-0000-0000-000000000001','2025-12-10','09:30:00','completed','Pre-holiday session',NOW()),
('e0000001-0000-0000-0000-000000000004','b0000001-0000-0000-0000-000000000001','2026-01-22','10:00:00','completed','New year kickoff',NOW()),
('e0000001-0000-0000-0000-000000000005','b0000001-0000-0000-0000-000000000001','2026-02-19','09:00:00','completed','February session',NOW()),
('e0000001-0000-0000-0000-000000000006','b0000001-0000-0000-0000-000000000001','2026-03-18','10:30:00','reserved','Spring - Amphi registered',NOW()),
('e0000001-0000-0000-0000-000000000007','b0000001-0000-0000-0000-000000000001','2026-04-15','09:00:00','reserved','April - Flowing Wells',NOW()),
('e0000001-0000-0000-0000-000000000008','b0000001-0000-0000-0000-000000000001','2026-05-20','10:00:00','available','End of year celebration',NOW()),
('e0000001-0000-0000-0000-000000000009','b0000001-0000-0000-0000-000000000001','2026-06-10','09:00:00','available','Summer prep session',NOW()),
('e0000001-0000-0000-0000-000000000010','b0000001-0000-0000-0000-000000000001','2026-03-25','14:00:00','cancelled','Cancelled - school closure',NOW()),
('e0000001-0000-0000-0000-000000000011','b0000001-0000-0000-0000-000000000002','2026-09-17','09:00:00','available','Fall 2026 opening',NOW()),
('e0000001-0000-0000-0000-000000000012','b0000001-0000-0000-0000-000000000002','2026-10-15','10:00:00','available','October session',NOW());

-- 9. EVENT REGISTRATIONS
INSERT INTO event_registrations (id, event_id, school_id, anticipated_students, requested_time, special_requests, registered_by, confirmation_sent, confirmation_sent_at, registered_at) VALUES
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000001',120,'09:00:00','Need extra chairs','a0000001-0000-0000-0000-000000000020',true,NOW(),NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000002','c0000001-0000-0000-0000-000000000004',85,'10:00:00',NULL,'a0000001-0000-0000-0000-000000000021',true,NOW(),NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000003','c0000001-0000-0000-0000-000000000002',95,'09:30:00','Bus at 9:15','a0000001-0000-0000-0000-000000000001',true,NOW(),NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000004','c0000001-0000-0000-0000-000000000003',110,'10:00:00',NULL,'a0000001-0000-0000-0000-000000000001',true,NOW(),NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000005','c0000001-0000-0000-0000-000000000005',75,'09:00:00','Wheelchair access needed','a0000001-0000-0000-0000-000000000001',true,NOW(),NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000006','c0000001-0000-0000-0000-000000000001',130,'10:30:00',NULL,'a0000001-0000-0000-0000-000000000020',true,NOW(),NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000007','c0000001-0000-0000-0000-000000000004',90,'09:00:00','Bringing own supplies','a0000001-0000-0000-0000-000000000021',true,NOW(),NOW());

-- 10. VOLUNTEER SIGNUPS
INSERT INTO volunteer_event_signups (id, event_id, volunteer_id, class_id, confirmation_sent, reminder_14d_sent, reminder_4d_sent, signed_up_at) VALUES
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000010','d0000001-0000-0000-0000-000000000001',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000011','d0000001-0000-0000-0000-000000000002',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000012','d0000001-0000-0000-0000-000000000003',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000010','d0000001-0000-0000-0000-000000000001',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000013','d0000001-0000-0000-0000-000000000004',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000014','d0000001-0000-0000-0000-000000000005',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000011','d0000001-0000-0000-0000-000000000002',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000015','d0000001-0000-0000-0000-000000000006',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000010','d0000001-0000-0000-0000-000000000001',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000012','d0000001-0000-0000-0000-000000000003',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000005','a0000001-0000-0000-0000-000000000014','d0000001-0000-0000-0000-000000000005',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000005','a0000001-0000-0000-0000-000000000015','d0000001-0000-0000-0000-000000000006',true,true,true,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000006','a0000001-0000-0000-0000-000000000010','d0000001-0000-0000-0000-000000000001',true,false,false,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000006','a0000001-0000-0000-0000-000000000011','d0000001-0000-0000-0000-000000000002',true,false,false,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000006','a0000001-0000-0000-0000-000000000012','d0000001-0000-0000-0000-000000000003',true,false,false,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000007','a0000001-0000-0000-0000-000000000013','d0000001-0000-0000-0000-000000000004',true,false,false,NOW()),
(gen_random_uuid(),'e0000001-0000-0000-0000-000000000007','a0000001-0000-0000-0000-000000000014','d0000001-0000-0000-0000-000000000005',true,false,false,NOW());

-- 11. DONATIONS
INSERT INTO donations (id, donor_name, donor_email, donor_phone, donor_organization, amount, donation_date, donation_kind, description, letter_sent, academic_year_id, recorded_by, created_at, updated_at) VALUES
(gen_random_uuid(),'Tucson Community Foundation','grants@tcf.org','520-555-0301','Tucson Community Foundation',5000.00,'2025-08-15','cash','Annual program grant',true,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW()),
(gen_random_uuid(),'Wells Fargo Foundation','community@wf.com','520-555-0302','Wells Fargo',3500.00,'2025-09-01','cash','Financial literacy sponsorship',true,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW()),
(gen_random_uuid(),'Home Depot','donations@hd.com','520-555-0303','Home Depot',1200.00,'2025-09-20','in-kind','Tool kits for auto class',true,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW()),
(gen_random_uuid(),'Frys Food Stores','community@frys.com','520-555-0304','Frys Food',800.00,'2025-10-05','in-kind','Cooking supplies for 4 sessions',true,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW()),
(gen_random_uuid(),'Bank of America','giving@bofa.com','520-555-0305','Bank of America',7500.00,'2025-11-01','cash','Financial literacy materials',true,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW()),
(gen_random_uuid(),'Arizona Complete Health','outreach@azch.com','520-555-0306','Arizona Complete Health',2000.00,'2025-12-01','cash','First aid kit supplies',false,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW()),
(gen_random_uuid(),'Robert Smith','rsmith@gmail.com','520-555-0307',NULL,500.00,'2026-01-15','cash','Personal donation',false,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW()),
(gen_random_uuid(),'Rotary Club of Tucson','service@rotary.org','520-555-0308','Rotary Club',2500.00,'2026-02-01','cash','Spring semester support',false,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW()),
(gen_random_uuid(),'Office Depot','business@od.com','520-555-0309','Office Depot',600.00,'2026-02-15','in-kind','Resume paper and folders',false,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000002',NOW(),NOW()),
(gen_random_uuid(),'Raytheon Community Fund','community@ray.com','520-555-0310','Raytheon',10000.00,'2026-03-01','cash','Annual STEM partnership grant',false,'b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',NOW(),NOW());

-- 12. VOLUNTEER SURVEYS
INSERT INTO volunteer_surveys (id, volunteer_id, academic_year_id, event_id, q1_participate_next_year, q2_recruit_contacts, q3_time_feedback, q4_take_home_items, q5_hands_on_satisfaction, q6_comments, submitted_at) VALUES
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000010','b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000001','yes','3 colleagues interested','just_right','yes','Students loved the budgeting exercise','Great experience! Students were very engaged.',NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000011','b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000001','yes','2 from my HR team','just_right','yes','Resume templates were a hit','Excellent questions from students about formatting.',NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000013','b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000002','yes','5 from nutrition dept','too_short','yes','Making pasta from scratch was amazing','Cooking class was a huge hit!',NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000015','b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000003','maybe','1 colleague','too_short','no','Need more time for mock interviews','Good session but need longer time slots.',NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000012','b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000004','yes','4 from safety team','just_right','yes','Every student learned CPR basics','Very rewarding experience.',NOW()),
(gen_random_uuid(),'a0000001-0000-0000-0000-000000000014','b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000005','yes','2 mechanics','too_long','yes','Tire changing was popular','Need better space for the display.',NOW());

-- 13. STUDENT SURVEYS
INSERT INTO student_surveys (id, academic_year_id, event_id, school_id, q1_learned_new_skill, q2_speaker_engaging, q3_share_with_family, q4_sessions_attended, q5_favorite_session, q6_improvement_suggestions, entered_by, entered_at) VALUES
(gen_random_uuid(),'b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000001','yes','very','yes','Financial Literacy, Resume Writing','Financial Literacy','More hands-on activities please!','a0000001-0000-0000-0000-000000000001',NOW()),
(gen_random_uuid(),'b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000001','yes','very','yes','Resume Writing, Interview Skills','Resume Writing','I have a real resume now!','a0000001-0000-0000-0000-000000000001',NOW()),
(gen_random_uuid(),'b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000002','c0000001-0000-0000-0000-000000000004','yes','somewhat','yes','Cooking Basics','Cooking Basics','We made real food! Best day ever.','a0000001-0000-0000-0000-000000000002',NOW()),
(gen_random_uuid(),'b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000003','c0000001-0000-0000-0000-000000000002','yes','very','yes','First Aid, Auto Maintenance','First Aid','I want to be a nurse now!','a0000001-0000-0000-0000-000000000001',NOW()),
(gen_random_uuid(),'b0000001-0000-0000-0000-000000000001','e0000001-0000-0000-0000-000000000004','c0000001-0000-0000-0000-000000000003','yes','very','yes','All of them!','Financial Literacy','Best day of school ever!','a0000001-0000-0000-0000-000000000002',NOW());

-- 14. SCHOOL SURVEYS
INSERT INTO school_surveys (id, academic_year_id, school_id, q1_school_name, q2_role, q3_fills_gap, q4_improvements, q5_additional_comments, entered_by, entered_at) VALUES
(gen_random_uuid(),'b0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000001','Amphi Middle School','School Admin','yes','Could start 15 min later for bus schedule','Outstanding program. Students talked about it for weeks. Would love to do it again.','a0000001-0000-0000-0000-000000000001',NOW()),
(gen_random_uuid(),'b0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000004','Flowing Wells Jr High','POC','yes','More variety in class offerings','Well organized. Volunteers were professional and engaging.','a0000001-0000-0000-0000-000000000002',NOW()),
(gen_random_uuid(),'b0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000002','Cross Middle School','Teacher','yes','None - it was perfect','Teachers loved watching students engaged with real-world skills.','a0000001-0000-0000-0000-000000000001',NOW());

-- VERIFY
SELECT 'Users' AS entity, COUNT(*) AS count FROM users
UNION ALL SELECT 'Academic Years', COUNT(*) FROM academic_years
UNION ALL SELECT 'Schools', COUNT(*) FROM schools
UNION ALL SELECT 'Principals', COUNT(*) FROM school_principals
UNION ALL SELECT 'Photo Restrictions', COUNT(*) FROM photo_restrictions
UNION ALL SELECT 'Life Skills Classes', COUNT(*) FROM life_skills_classes
UNION ALL SELECT 'Volunteer Profiles', COUNT(*) FROM volunteer_profiles
UNION ALL SELECT 'Events', COUNT(*) FROM lbb_events
UNION ALL SELECT 'Registrations', COUNT(*) FROM event_registrations
UNION ALL SELECT 'Volunteer Signups', COUNT(*) FROM volunteer_event_signups
UNION ALL SELECT 'Donations', COUNT(*) FROM donations
UNION ALL SELECT 'Volunteer Surveys', COUNT(*) FROM volunteer_surveys
UNION ALL SELECT 'Student Surveys', COUNT(*) FROM student_surveys
UNION ALL SELECT 'School Surveys', COUNT(*) FROM school_surveys
ORDER BY entity;
