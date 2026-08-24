'use client';

import * as React from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { updateProfile } from 'firebase/auth';
import { doc, getDoc, setDoc, collection, query, where, getDocs, updateDoc } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { format } from 'date-fns';
import { Calendar as CalendarIcon, Camera, Home } from 'lucide-react';
import Link from 'next/link';

import { useAuth } from '@/contexts/auth-context';
import { Button } from '@/components/ui/button';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { useToast } from '@/hooks/use-toast';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Icons } from '@/components/icons';
import { db, storage } from '@/lib/firebase';
import { cn } from '@/lib/utils';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Calendar } from '@/components/ui/calendar';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { Textarea } from '@/components/ui/textarea';
import { Skeleton } from '@/components/ui/skeleton';

const profileSchema = z.object({
  // From 'users' collection
  name: z.string().min(2, { message: 'O nome deve ter pelo menos 2 caracteres.' }),
  dataNascimento: z.date().optional(),
  sexo: z.enum(['Masculino', 'Feminino', 'Outro']).optional(),

  // From 'tb_medicos' collection
  telefone: z.string().optional(),
  crm: z.string().optional(),
  especialidades: z.string().optional(), // Will be handled as a comma-separated string
  endereco: z.string().optional(),
  biografia: z.string().optional(),
});

type ProfileFormValues = z.infer<typeof profileSchema>;

export default function ProfilePage() {
  const { user, isDoctor, doctorId, doctorProfile, userProfile } = useAuth();
  const { toast } = useToast();
  const [isPending, startTransition] = React.useTransition();
  const [isNewUserDoc, setIsNewUserDoc] = React.useState(false);
  const [profileImage, setProfileImage] = React.useState<File | null>(null);
  const [previewImageUrl, setPreviewImageUrl] = React.useState<string | null>(null);
  const [loadingProfile, setLoadingProfile] = React.useState(true);


  const form = useForm<ProfileFormValues>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      name: '',
      telefone: '',
      crm: '',
      especialidades: '',
      endereco: '',
      biografia: '',
      dataNascimento: undefined,
      sexo: undefined,
    },
  });

  React.useEffect(() => {
    const fetchProfileData = async () => {
      setLoadingProfile(true);
      if (user) {
          // A 'user' doc might not exist yet for a doctor.
          const userDocRef = doc(db, 'users', user.uid);
          const docSnap = await getDoc(userDocRef);

          if (!docSnap.exists()) {
              setIsNewUserDoc(true);
          } else {
              setIsNewUserDoc(false);
          }
          
          // Populate form with data from Auth, then from Firestore 'users' and 'tb_medicos'
          let defaultValues: Partial<ProfileFormValues> = {
              name: user.displayName || '',
          };

          if(userProfile) {
              defaultValues = {
                ...defaultValues,
                dataNascimento: userProfile.dataNascimento?.toDate(),
                sexo: userProfile.sexo,
              }
          }

          if(isDoctor && doctorProfile) {
              defaultValues = {
                  ...defaultValues,
                  name: doctorProfile.nomeCompleto || user.displayName || '',
                  telefone: doctorProfile.telefone,
                  crm: doctorProfile.crm,
                  especialidades: doctorProfile.especialidades?.join(', '),
                  endereco: doctorProfile.endereco,
                  biografia: doctorProfile.biografia,
              }
          }
          
          form.reset(defaultValues);
      }
      setLoadingProfile(false);
    }
    fetchProfileData();
  }, [user, userProfile, doctorProfile, isDoctor, form]);


  const handleProfileUpdate = (values: ProfileFormValues) => {
    if (!user) return;
    
    startTransition(async () => {
      try {
        let photoURL = user.photoURL;

        if (profileImage) {
          const storageRef = ref(storage, `profile_pictures/${user.uid}`);
          await uploadBytes(storageRef, profileImage);
          photoURL = await getDownloadURL(storageRef);
        }

        // 1. Update Firebase Auth Profile
        if (values.name !== user.displayName || photoURL !== user.photoURL) {
          await updateProfile(user, { 
            displayName: values.name,
            photoURL: photoURL,
          });
        }
        
        // 2. Create or Update 'users' collection document
        const userDocRef = doc(db, 'users', user.uid);
        const userData: any = {
          display_name: values.name,
          email: user.email,
          uid: user.uid,
          photo_url: photoURL,
          dataNascimento: values.dataNascimento,
          sexo: values.sexo,
          updatedAt: new Date(),
        };

        if (isNewUserDoc) {
          userData.created_time = new Date();
          if(isDoctor) {
            userData.roles = ['med'];
          }
        }
        await setDoc(userDocRef, userData, { merge: true });

        // 3. Update 'tb_medicos' if user is a doctor
        if (isDoctor && doctorId) {
            const medicoDocRef = doc(db, 'tb_medicos', doctorId);
            const medicoData = {
                nomeCompleto: values.name || '',
                telefone: values.telefone || '',
                crm: values.crm || '',
                especialidades: values.especialidades?.split(',').map(s => s.trim()).filter(Boolean) || [],
                endereco: values.endereco || '',
                biografia: values.biografia || '',
                fotoPerfil: photoURL || '',
            };
            await updateDoc(medicoDocRef, medicoData);
        }

        toast({
          title: 'Sucesso!',
          description: 'Seu perfil foi atualizado.',
        });

        // Reset image states after successful upload
        setProfileImage(null);
        setPreviewImageUrl(null);
        setIsNewUserDoc(false);

      } catch (error: any) {
        console.error("Profile update error:", error);
        toast({
          variant: 'destructive',
          title: 'Erro ao atualizar perfil',
          description: error.message || 'Ocorreu um erro. Por favor, tente novamente.',
        });
      }
    });
  };

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
        const file = e.target.files[0];
        setProfileImage(file);
        setPreviewImageUrl(URL.createObjectURL(file));
    }
  };
  
  const getInitials = (name: string | null | undefined) => {
    if (!name) return 'U';
    return name.split(' ').map(n => n[0]).slice(0, 2).join('').toUpperCase();
  }
  
  const currentAvatarSrc = previewImageUrl || (isDoctor ? doctorProfile?.fotoPerfil : userProfile?.photo_url) || user?.photoURL;

  if (loadingProfile) {
      return (
          <div className="space-y-8">
              <Skeleton className="h-10 w-1/3" />
              <Card>
                  <CardHeader><Skeleton className="h-24 w-full" /></CardHeader>
                  <CardContent><Skeleton className="h-64 w-full" /></CardContent>
              </Card>
          </div>
      )
  }

  return (
    <div className="flex flex-col gap-8">
      <div className='flex justify-between items-start'>
        <div>
          <h1 className="font-headline text-3xl font-semibold text-primary">Meu Perfil</h1>
          <p className="text-muted-foreground">
            Gerencie suas informações pessoais e profissionais.
          </p>
        </div>
        {isDoctor && (
          <Button asChild variant="outline">
            <Link href="/doctor/dashboard">
              <Home className="mr-2 h-4 w-4" />
              Voltar ao Início
            </Link>
          </Button>
        )}
      </div>
      
      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <div className='relative'>
                <Avatar className="h-20 w-20">
                    <AvatarImage src={currentAvatarSrc || undefined} alt={user?.displayName || 'User'} />
                    <AvatarFallback className="text-2xl">{getInitials(user?.displayName)}</AvatarFallback>
                </Avatar>
                <input 
                    type="file" 
                    ref={fileInputRef} 
                    onChange={handleImageChange}
                    className="hidden"
                    accept="image/png, image/jpeg"
                />
                <Button 
                    size="icon" 
                    variant="outline"
                    className="absolute bottom-0 right-0 rounded-full h-7 w-7 bg-background/80"
                    onClick={() => fileInputRef.current?.click()}
                    disabled={isPending}
                >
                    <Camera className="h-4 w-4" />
                    <span className="sr-only">Alterar foto</span>
                </Button>
            </div>
            <div>
              <CardTitle>{form.watch('name') || 'Usuário'}</CardTitle>
              <CardDescription>{user?.email}</CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(handleProfileUpdate)} className="space-y-8 max-w-4xl">
              
              {/* --- Common Fields --- */}
              <fieldset className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <legend className="font-headline text-lg font-semibold col-span-full mb-2 border-b pb-2 text-primary">Informações Pessoais</legend>
                <FormField
                  control={form.control}
                  name="name"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Nome Completo</FormLabel>
                      <FormControl>
                        <Input placeholder="Seu nome completo" {...field} disabled={isPending} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="dataNascimento"
                  render={({ field }) => (
                    <FormItem className="flex flex-col">
                      <FormLabel>Data de Nascimento</FormLabel>
                      <Popover>
                        <PopoverTrigger asChild>
                          <FormControl>
                            <Button
                              variant={"outline"}
                              className={cn(
                                "pl-3 text-left font-normal",
                                !field.value && "text-muted-foreground"
                              )}
                              disabled={isPending}
                            >
                              {field.value ? (
                                format(field.value, "dd/MM/yyyy")
                              ) : (
                                <span>Escolha uma data</span>
                              )}
                              <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                            </Button>
                          </FormControl>
                        </PopoverTrigger>
                        <PopoverContent className="w-auto p-0" align="start">
                          <Calendar
                            mode="single"
                            selected={field.value}
                            onSelect={field.onChange}
                            disabled={(date) =>
                              date > new Date() || date < new Date("1900-01-01")
                            }
                            initialFocus
                          />
                        </PopoverContent>
                      </Popover>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="sexo"
                  render={({ field }) => (
                    <FormItem className="space-y-3">
                      <FormLabel>Sexo</FormLabel>
                      <FormControl>
                        <RadioGroup
                          onValueChange={field.onChange}
                          value={field.value}
                          className="flex flex-row space-x-4 items-center pt-2"
                          disabled={isPending}
                        >
                          <FormItem className="flex items-center space-x-2 space-y-0">
                            <FormControl>
                              <RadioGroupItem value="Masculino" />
                            </FormControl>
                            <FormLabel className="font-normal">
                              Masculino
                            </FormLabel>
                          </FormItem>
                          <FormItem className="flex items-center space-x-2 space-y-0">
                            <FormControl>
                              <RadioGroupItem value="Feminino" />
                            </FormControl>
                            <FormLabel className="font-normal">
                              Feminino
                            </FormLabel>
                          </FormItem>
                          <FormItem className="flex items-center space-x-2 space-y-0">
                            <FormControl>
                              <RadioGroupItem value="Outro" />
                            </FormControl>
                            <FormLabel className="font-normal">Outro</FormLabel>
                          </FormItem>
                        </RadioGroup>
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </fieldset>

              {/* --- Doctor-specific Fields --- */}
              {isDoctor && (
                <fieldset className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <legend className="font-headline text-lg font-semibold col-span-full mb-2 border-b pb-2 text-primary">Informações Profissionais</legend>
                    <FormField
                      control={form.control}
                      name="crm"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>CRM</FormLabel>
                          <FormControl>
                            <Input placeholder="000000/SP" {...field} disabled={isPending} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                     <FormField
                      control={form.control}
                      name="telefone"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel>Telefone de Contato</FormLabel>
                          <FormControl>
                            <Input placeholder="(00) 00000-0000" {...field} disabled={isPending} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="especialidades"
                      render={({ field }) => (
                        <FormItem className="md:col-span-2">
                          <FormLabel>Especialidades</FormLabel>
                          <FormControl>
                            <Input placeholder="Cardiologia, Pediatria..." {...field} disabled={isPending} />
                          </FormControl>
                          <p className='text-xs text-muted-foreground'>Separe as especialidades por vírgula.</p>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                     <FormField
                      control={form.control}
                      name="endereco"
                      render={({ field }) => (
                        <FormItem className="md:col-span-2">
                          <FormLabel>Endereço Profissional</FormLabel>
                          <FormControl>
                            <Input placeholder="Sua rua, número, bairro..." {...field} disabled={isPending} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="biografia"
                      render={({ field }) => (
                        <FormItem className="md:col-span-2">
                          <FormLabel>Biografia</FormLabel>
                          <FormControl>
                            <Textarea rows={4} placeholder="Fale um pouco sobre sua carreira, foco de atuação, etc." {...field} disabled={isPending} />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                </fieldset>
              )}

              <Button type="submit" disabled={isPending}>
                {isPending && <Icons.Logo className="mr-2 h-4 w-4 animate-spin" />}
                Salvar Alterações
              </Button>
            </form>
          </Form>
        </CardContent>
      </Card>
    </div>
  );
}
