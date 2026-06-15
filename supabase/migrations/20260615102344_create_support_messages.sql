CREATE TABLE support_messages (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  email      text NOT NULL,
  message    text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "insert_support_messages" ON support_messages FOR INSERT
  TO anon WITH CHECK (true);

CREATE POLICY "select_support_messages" ON support_messages FOR SELECT
  TO anon USING (false);
