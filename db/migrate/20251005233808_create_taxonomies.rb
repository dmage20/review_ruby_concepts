class CreateTaxonomies < ActiveRecord::Migration[7.2]
  def change
    create_table :taxonomies do |t|
      t.string :code, null: false, limit: 10
      t.string :classification, limit: 200
      t.string :specialization, limit: 200
      t.text :description

      t.timestamps
    end

    add_index :taxonomies, :code, unique: true
    add_index :taxonomies, :classification
    add_index :taxonomies, :specialization

    # Seed common taxonomies
    reversible do |dir|
      dir.up do
        taxonomies_data = [
          [ '207Q00000X', 'Allopathic & Osteopathic Physicians', 'Family Medicine', 'A physician who specializes in family medicine' ],
          [ '208D00000X', 'Allopathic & Osteopathic Physicians', 'General Practice', 'A physician who provides general medical care' ],
          [ '207R00000X', 'Allopathic & Osteopathic Physicians', 'Internal Medicine', 'A physician who specializes in internal medicine' ],
          [ '207V00000X', 'Allopathic & Osteopathic Physicians', 'Obstetrics & Gynecology', 'A physician specializing in women\'s health' ],
          [ '208000000X', 'Allopathic & Osteopathic Physicians', 'Pediatrics', 'A physician who specializes in children\'s health' ],
          [ '207T00000X', 'Allopathic & Osteopathic Physicians', 'Neurological Surgery', 'A physician specializing in brain and nerve surgery' ],
          [ '207N00000X', 'Allopathic & Osteopathic Physicians', 'Dermatology', 'A physician specializing in skin conditions' ],
          [ '207K00000X', 'Allopathic & Osteopathic Physicians', 'Allergy & Immunology', 'A physician specializing in allergies and immune system' ],
          [ '207L00000X', 'Allopathic & Osteopathic Physicians', 'Anesthesiology', 'A physician specializing in anesthesia' ],
          [ '207W00000X', 'Allopathic & Osteopathic Physicians', 'Ophthalmology', 'A physician specializing in eye care' ],
          [ '207X00000X', 'Allopathic & Osteopathic Physicians', 'Orthopaedic Surgery', 'A physician specializing in bone and joint surgery' ],
          [ '207Y00000X', 'Allopathic & Osteopathic Physicians', 'Otolaryngology', 'A physician specializing in ear, nose, and throat' ],
          [ '208100000X', 'Allopathic & Osteopathic Physicians', 'Physical Medicine & Rehabilitation', 'A physician specializing in rehabilitation' ],
          [ '208200000X', 'Allopathic & Osteopathic Physicians', 'Plastic Surgery', 'A physician specializing in reconstructive surgery' ],
          [ '208G00000X', 'Allopathic & Osteopathic Physicians', 'Thoracic Surgery (Cardiothoracic Vascular Surgery)', 'A physician specializing in chest surgery' ],
          [ '208C00000X', 'Allopathic & Osteopathic Physicians', 'Colon & Rectal Surgery', 'A physician specializing in colon and rectal surgery' ],
          [ '208M00000X', 'Allopathic & Osteopathic Physicians', 'Hospitalist', 'A physician who practices in a hospital setting' ],
          [ '363L00000X', 'Physician Assistants & Advanced Practice Nursing Providers', 'Nurse Practitioner', 'An advanced practice registered nurse' ],
          [ '363A00000X', 'Physician Assistants & Advanced Practice Nursing Providers', 'Physician Assistant', 'A healthcare professional who practices medicine under supervision' ],
          [ '364S00000X', 'Physician Assistants & Advanced Practice Nursing Providers', 'Clinical Nurse Specialist', 'An advanced practice nurse with specialized expertise' ],
          [ '367500000X', 'Physician Assistants & Advanced Practice Nursing Providers', 'Nurse Anesthetist, Certified Registered', 'An advanced practice nurse specializing in anesthesia' ],
          [ '367A00000X', 'Physician Assistants & Advanced Practice Nursing Providers', 'Advanced Practice Midwife', 'An advanced practice nurse specializing in midwifery' ],
          [ '163W00000X', 'Nursing Service Providers', 'Registered Nurse', 'A licensed nurse providing patient care' ],
          [ '164W00000X', 'Nursing Service Providers', 'Licensed Practical Nurse', 'A licensed nurse providing basic patient care' ],
          [ '122300000X', 'Dental Providers', 'Dentist', 'A dental healthcare provider' ],
          [ '1223G0001X', 'Dental Providers', 'General Practice', 'A dentist providing general dental care' ],
          [ '1223P0221X', 'Dental Providers', 'Periodontics', 'A dentist specializing in gum disease' ],
          [ '1223E0200X', 'Dental Providers', 'Endodontics', 'A dentist specializing in root canal treatment' ],
          [ '1223S0112X', 'Dental Providers', 'Oral and Maxillofacial Surgery', 'A dentist specializing in oral surgery' ],
          [ '1223X0400X', 'Dental Providers', 'Orthodontics and Dentofacial Orthopedics', 'A dentist specializing in teeth alignment' ],
          [ '152W00000X', 'Eye and Vision Services Providers', 'Optometrist', 'A provider of vision and eye care' ],
          [ '133V00000X', 'Dietary & Nutritional Service Providers', 'Dietitian, Registered', 'A registered dietitian providing nutrition care' ],
          [ '225100000X', 'Respiratory, Developmental, Rehabilitative and Restorative Service Providers', 'Physical Therapist', 'A provider of physical therapy' ],
          [ '225X00000X', 'Respiratory, Developmental, Rehabilitative and Restorative Service Providers', 'Occupational Therapist', 'A provider of occupational therapy' ],
          [ '235Z00000X', 'Respiratory, Developmental, Rehabilitative and Restorative Service Providers', 'Speech-Language Pathologist', 'A provider of speech therapy' ],
          [ '261QR1300X', 'Ambulatory Health Care Facilities', 'Clinic/Center, Radiology', 'A facility providing radiology services' ],
          [ '261QM0850X', 'Ambulatory Health Care Facilities', 'Clinic/Center, Adult Mental Health', 'A facility providing mental health services' ],
          [ '282N00000X', 'Hospitals', 'General Acute Care Hospital', 'A general hospital' ],
          [ '283Q00000X', 'Hospitals', 'Psychiatric Hospital', 'A psychiatric hospital' ],
          [ '291U00000X', 'Residential Treatment Facilities', 'Rehabilitation, Substance Use Disorder', 'A substance abuse treatment facility' ]
        ]

        taxonomies_data.each do |code, classification, specialization, description|
          execute <<-SQL
            INSERT INTO taxonomies (code, classification, specialization, description, created_at, updated_at)
            VALUES (
              '#{code}',
              '#{classification.gsub("'", "''")}',
              '#{specialization.gsub("'", "''")}',
              '#{description.gsub("'", "''")}',
              NOW(),
              NOW()
            )
          SQL
        end
      end
    end
  end
end
