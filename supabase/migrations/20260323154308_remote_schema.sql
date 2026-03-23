


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";





SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."cycles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "text",
    "status" "text" NOT NULL,
    "start_date" "text",
    "end_date" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."cycles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."deleted_expenses" (
    "expense_id" "text" NOT NULL,
    "group_id" "text",
    "deleted_by_id" "text",
    "deleted_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."deleted_expenses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expense_revisions" (
    "expense_id" "text" NOT NULL,
    "group_id" "text",
    "replaces_expense_id" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."expense_revisions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expense_splits" (
    "expense_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "amount" double precision,
    "amount_minor" integer
);


ALTER TABLE "public"."expense_splits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expenses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cycle_id" "uuid",
    "group_id" "text",
    "description" "text" NOT NULL,
    "amount" double precision NOT NULL,
    "amount_minor" integer,
    "expense_date" "text" NOT NULL,
    "paid_by_id" "uuid",
    "created_by_id" "uuid",
    "category" "text",
    "split_type" "text" DEFAULT 'Even'::"text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."expenses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fcm_tokens" (
    "user_id" "text" NOT NULL,
    "token" "text" NOT NULL,
    "platform" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."fcm_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."group_members" (
    "group_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."group_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."groups" (
    "id" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "status" "text" NOT NULL,
    "amount" double precision DEFAULT 0.0,
    "status_line" "text",
    "creator_id" "uuid",
    "currency_code" "text" DEFAULT 'INR'::"text",
    "invite_link_token" "text",
    "invite_link_enabled" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "active_cycle_id" "text",
    "pending_members" "jsonb",
    "settlement_rhythm" "text" DEFAULT 'weekly'::"text",
    "settlement_day" integer DEFAULT 0
);


ALTER TABLE "public"."groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_attempts" (
    "id" "text" NOT NULL,
    "group_id" "text",
    "cycle_id" "uuid",
    "payer_id" "text" NOT NULL,
    "payee_id" "text" NOT NULL,
    "amount_minor" integer NOT NULL,
    "currency" "text" NOT NULL,
    "status" "text" NOT NULL,
    "created_at" bigint NOT NULL,
    "updated_at" bigint NOT NULL
);


ALTER TABLE "public"."payment_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."settlement_events" (
    "id" "text" NOT NULL,
    "group_id" "text",
    "type" "text" NOT NULL,
    "amount_minor" integer,
    "currency_code" "text",
    "payment_attempt_id" "text",
    "pending_count" integer,
    "timestamp" bigint NOT NULL
);


ALTER TABLE "public"."settlement_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."system_messages" (
    "id" "text" NOT NULL,
    "group_id" "text",
    "type" "text" NOT NULL,
    "user_id" "text",
    "user_name" "text",
    "detail" "text",
    "prefix" "text",
    "timestamp" bigint NOT NULL
);


ALTER TABLE "public"."system_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "phone" "text",
    "display_name" "text",
    "avatar_url" "text",
    "upi_id" "text",
    "currency_code" "text" DEFAULT 'INR'::"text",
    "is_beta" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "email" "text"
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."cycles"
    ADD CONSTRAINT "cycles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."deleted_expenses"
    ADD CONSTRAINT "deleted_expenses_pkey" PRIMARY KEY ("expense_id");



ALTER TABLE ONLY "public"."expense_revisions"
    ADD CONSTRAINT "expense_revisions_pkey" PRIMARY KEY ("expense_id");



ALTER TABLE ONLY "public"."expense_splits"
    ADD CONSTRAINT "expense_splits_pkey" PRIMARY KEY ("expense_id", "user_id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fcm_tokens"
    ADD CONSTRAINT "fcm_tokens_pkey" PRIMARY KEY ("user_id", "token");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_pkey" PRIMARY KEY ("group_id", "user_id");



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_attempts"
    ADD CONSTRAINT "payment_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."settlement_events"
    ADD CONSTRAINT "settlement_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."system_messages"
    ADD CONSTRAINT "system_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cycles"
    ADD CONSTRAINT "cycles_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."deleted_expenses"
    ADD CONSTRAINT "deleted_expenses_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_revisions"
    ADD CONSTRAINT "expense_revisions_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_splits"
    ADD CONSTRAINT "expense_splits_expense_id_fkey" FOREIGN KEY ("expense_id") REFERENCES "public"."expenses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_splits"
    ADD CONSTRAINT "expense_splits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_cycle_id_fkey" FOREIGN KEY ("cycle_id") REFERENCES "public"."cycles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_paid_by_id_fkey" FOREIGN KEY ("paid_by_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."payment_attempts"
    ADD CONSTRAINT "payment_attempts_cycle_id_fkey" FOREIGN KEY ("cycle_id") REFERENCES "public"."cycles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payment_attempts"
    ADD CONSTRAINT "payment_attempts_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."settlement_events"
    ADD CONSTRAINT "settlement_events_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."system_messages"
    ADD CONSTRAINT "system_messages_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Anyone can view group info" ON "public"."groups" FOR SELECT USING (true);



CREATE POLICY "Authed users can add members" ON "public"."group_members" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can create expenses" ON "public"."expenses" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can create splits" ON "public"."expense_splits" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can delete expenses" ON "public"."expenses" FOR DELETE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can delete splits" ON "public"."expense_splits" FOR DELETE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can update expenses" ON "public"."expenses" FOR UPDATE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can update splits" ON "public"."expense_splits" FOR UPDATE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can view and insert deleted expenses" ON "public"."deleted_expenses" USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can view and insert expense revisions" ON "public"."expense_revisions" USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can view and insert settlement events" ON "public"."settlement_events" USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can view and insert system messages" ON "public"."system_messages" USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can view and update payment attempts" ON "public"."payment_attempts" USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can view expenses" ON "public"."expenses" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can view members" ON "public"."group_members" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authed users can view splits" ON "public"."expense_splits" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Authenticated users can create groups" ON "public"."groups" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Group members can create cycles" ON "public"."cycles" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Group members can manage expenses" ON "public"."expenses" USING ((EXISTS ( SELECT 1
   FROM "public"."group_members"
  WHERE (("group_members"."group_id" = "expenses"."group_id") AND ("group_members"."user_id" = "auth"."uid"())))));



CREATE POLICY "Group members can update cycles" ON "public"."cycles" FOR UPDATE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Group members can update group" ON "public"."groups" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."group_members"
  WHERE (("group_members"."group_id" = "groups"."id") AND ("group_members"."user_id" = "auth"."uid"())))));



CREATE POLICY "Group members can view cycles" ON "public"."cycles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."group_members"
  WHERE (("group_members"."group_id" = "cycles"."group_id") AND ("group_members"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can manage their own FCM tokens" ON "public"."fcm_tokens" USING ((("auth"."uid"())::"text" = "user_id"));



CREATE POLICY "Users can view and update their own profile" ON "public"."users" USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view groups they are members of" ON "public"."groups" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."group_members"
  WHERE (("group_members"."group_id" = "groups"."id") AND ("group_members"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."cycles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."deleted_expenses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expense_revisions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expense_splits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expenses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fcm_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."group_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payment_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."settlement_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."system_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."cycles";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."deleted_expenses";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."expense_revisions";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."expense_splits";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."expenses";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."group_members";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."groups";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."payment_attempts";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."settlement_events";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."system_messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."users";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";








































































































































































GRANT ALL ON TABLE "public"."cycles" TO "anon";
GRANT ALL ON TABLE "public"."cycles" TO "authenticated";
GRANT ALL ON TABLE "public"."cycles" TO "service_role";



GRANT ALL ON TABLE "public"."deleted_expenses" TO "anon";
GRANT ALL ON TABLE "public"."deleted_expenses" TO "authenticated";
GRANT ALL ON TABLE "public"."deleted_expenses" TO "service_role";



GRANT ALL ON TABLE "public"."expense_revisions" TO "anon";
GRANT ALL ON TABLE "public"."expense_revisions" TO "authenticated";
GRANT ALL ON TABLE "public"."expense_revisions" TO "service_role";



GRANT ALL ON TABLE "public"."expense_splits" TO "anon";
GRANT ALL ON TABLE "public"."expense_splits" TO "authenticated";
GRANT ALL ON TABLE "public"."expense_splits" TO "service_role";



GRANT ALL ON TABLE "public"."expenses" TO "anon";
GRANT ALL ON TABLE "public"."expenses" TO "authenticated";
GRANT ALL ON TABLE "public"."expenses" TO "service_role";



GRANT ALL ON TABLE "public"."fcm_tokens" TO "anon";
GRANT ALL ON TABLE "public"."fcm_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."fcm_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."group_members" TO "anon";
GRANT ALL ON TABLE "public"."group_members" TO "authenticated";
GRANT ALL ON TABLE "public"."group_members" TO "service_role";



GRANT ALL ON TABLE "public"."groups" TO "anon";
GRANT ALL ON TABLE "public"."groups" TO "authenticated";
GRANT ALL ON TABLE "public"."groups" TO "service_role";



GRANT ALL ON TABLE "public"."payment_attempts" TO "anon";
GRANT ALL ON TABLE "public"."payment_attempts" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_attempts" TO "service_role";



GRANT ALL ON TABLE "public"."settlement_events" TO "anon";
GRANT ALL ON TABLE "public"."settlement_events" TO "authenticated";
GRANT ALL ON TABLE "public"."settlement_events" TO "service_role";



GRANT ALL ON TABLE "public"."system_messages" TO "anon";
GRANT ALL ON TABLE "public"."system_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."system_messages" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";


  create policy "Anyone can upload an avatar."
  on "storage"."objects"
  as permissive
  for insert
  to public
with check ((bucket_id = 'avatars'::text));



  create policy "Avatar images are publicly accessible."
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'avatars'::text));



  create policy "Users can update their own avatars."
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'avatars'::text) AND ((auth.uid())::text = (storage.foldername(name))[2])));



  create policy "Users can upload their own receipts."
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'receipts'::text) AND (auth.uid() IS NOT NULL)));



  create policy "Users can view and delete their own receipts."
  on "storage"."objects"
  as permissive
  for all
  to public
using (((bucket_id = 'receipts'::text) AND (auth.uid() IS NOT NULL)));



