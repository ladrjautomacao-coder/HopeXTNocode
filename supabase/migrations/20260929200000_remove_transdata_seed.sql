-- Este banco é o do produto HopeXT NoCode (separado da Transdata, que fica
-- isolada no repositório/Supabase/Vercel originais). O histórico de
-- migrations recria o tenant "semente" da Transdata (criado na Fase 1,
-- antes de existir o repositório novo) — removendo aqui, sem nenhum vínculo.
-- ON DELETE CASCADE (já configurado em 20260925150000) cuida de apagar
-- junto qualquer catálogo (tipos de projeto, soluções etc.) que tinha sido
-- semeado pra esse tenant antes de tenant_id existir.
DELETE FROM public.tenants WHERE id = 'a2f1c8e0-0000-4000-8000-000000000001';

-- handle_new_user() tinha a Transdata como fallback de tenant_id quando o
-- metadata não trouxesse um. Nesse banco esse UUID não existe mais — em vez
-- de continuar apontando pra um tenant fantasma (causaria erro de FK na hora
-- H), o cadastro de usuário passa a EXIGIR tenant_id explícito. Os dois
-- fluxos que criam usuário hoje (public-signup e admin-users) já mandam
-- tenant_id sempre, então isso não muda nada na prática — só remove um
-- fallback que nunca deveria ter sido acionado.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.raw_user_meta_data->>'tenant_id' IS NULL THEN
    RAISE EXCEPTION 'tenant_id é obrigatório para criar um novo usuário';
  END IF;
  INSERT INTO public.profiles (user_id, full_name, cargo, tenant_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    NEW.raw_user_meta_data->>'cargo',
    (NEW.raw_user_meta_data->>'tenant_id')::uuid
  )
  ON CONFLICT DO NOTHING;
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user')
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$function$;
