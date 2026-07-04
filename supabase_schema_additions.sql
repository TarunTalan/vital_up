-- Create a table for user health data (Onboarding payload)
CREATE TABLE public.user_health_data (
  id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL PRIMARY KEY,
  full_name TEXT,
  dob TEXT,
  gender TEXT,
  weight TEXT,
  weight_unit TEXT,
  height TEXT,
  height_unit TEXT,
  oxygen_level TEXT,
  health_conditions TEXT,
  medicines TEXT,
  allergies TEXT,
  smokes TEXT,
  blood_pressure_top TEXT,
  blood_pressure_bottom TEXT,
  bpm TEXT,
  activity TEXT,
  sleep TEXT,
  onboarding_completed BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.user_health_data ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies for user_health_data
-- Users can only view their own health data
CREATE POLICY "Users can view own health data." ON public.user_health_data 
  FOR SELECT USING (auth.uid() = id);

-- Users can insert their own health data
CREATE POLICY "Users can insert own health data." ON public.user_health_data 
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can update their own health data
CREATE POLICY "Users can update own health data." ON public.user_health_data 
  FOR UPDATE USING (auth.uid() = id);

-- Trigger to automatically update the updated_at column
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_health_data_modtime
BEFORE UPDATE ON public.user_health_data
FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
