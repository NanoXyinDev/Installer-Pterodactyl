<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Model;
use Illuminate\Support\Collection;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Spatie\QueryBuilder\QueryBuilder;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\Translation\Translator;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Services\Users\UserDeletionService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Http\Requests\Admin\NewUserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;

class UserController extends Controller
{
    use AvailableLanguages;

    /**
     * UserController constructor.
     */
    public function __construct(
        protected AlertsMessageBag $alert,
        protected UserCreationService $creationService,
        protected UserDeletionService $deletionService,
        protected Translator $translator,
        protected UserUpdateService $updateService,
        protected UserRepositoryInterface $repository,
        protected ViewFactory $view
    ) {
    }

    /**
     * Display user index page.
     */
public function index(Request $request): View
{
    $authUser = $request->user();

    $query = User::query()
        ->select('users.*')
        ->selectRaw('COUNT(DISTINCT(subusers.id)) as subuser_of_count')
        ->selectRaw('COUNT(DISTINCT(servers.id)) as servers_count')
        ->leftJoin('subusers', 'subusers.user_id', '=', 'users.id')
        ->leftJoin('servers', 'servers.owner_id', '=', 'users.id')
        ->groupBy('users.id');

    // Jika bukan admin ID 1, hanya tampilkan dirinya sendiri
    if ($authUser->id !== 1) {
        $query->where('users.id', $authUser->id);
    }

    $users = QueryBuilder::for($query)
        ->allowedFilters(['username', 'email', 'uuid'])
        ->allowedSorts(['id', 'uuid'])
        ->paginate(50);

    return $this->view->make('admin.users.index', ['users' => $users]);
}

    /**
     * Display new user page.
     */
    public function create(): View
    {
        return $this->view->make('admin.users.new', [
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Display user view page.
     */
    public function view(User $user): View
    {
        $authUser = request()->user();

        // HARDCORE IDOR GUARD: user hanya boleh membuka profilnya sendiri.
        // Admin utama (ID 1) tetap memiliki akses penuh.
        if (!$authUser || ($authUser->id !== 1 && $authUser->id !== $user->id)) {
            throw new DisplayException(
                "🚫 Akses ditolak: Anda tidak memiliki izin untuk melihat user ini. ©Protect By @XyrooXellz"
            );
        }

        return $this->view->make('admin.users.view', [
            'user' => $user,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * Delete a user from the system.
     *
     * @throws \Exception
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
public function delete(Request $request, User $user): RedirectResponse
{
    $authUser = $request->user();

    // ❌ Jika bukan admin ID 1 -> larang delete user manapun
    if ($authUser->id !== 1) {
        throw new DisplayException("🚫 Akses ditolak: hanya admin ID 1 yang dapat menghapus user! ©Protect By @XyrooXellz");
    }

    // ❌ Admin ID 1 tidak boleh hapus dirinya sendiri
    if ($authUser->id === $user->id) {
        throw new DisplayException("❌ Tidak bisa menghapus akun Anda sendiri.");
    }

    // Lanjut hapus user
    $this->deletionService->handle($user);

    $this->alert->success("🗑️ User berhasil dihapus.")->flash();
    return redirect()->route('admin.users');
}

    /**
     * Create a user.
     */
    public function store(NewUserFormRequest $request): RedirectResponse
    {
        $authUser = $request->user();
        $data = $request->normalize();

        // Jika user bukan admin ID 1 dan mencoba membuat user admin
        if ($authUser->id !== 1 && isset($data['root_admin']) && $data['root_admin'] == true) {
            throw new DisplayException("🚫 Akses ditolak: Hanya admin ID 1 yang dapat membuat user admin! ©Protect By @XyrooXellz.");
        }

        // Semua user selain ID 1 akan selalu membuat user biasa
        if ($authUser->id !== 1) {
            $data['root_admin'] = false;
        }

        // Buat user baru
        $user = $this->creationService->handle($data);

        $this->alert->success("✅ Akun user berhasil dibuat (level: user biasa).")->flash();
        return redirect()->route('admin.users.view', $user->id);
    }


    /**
     * Update a user on the system.
     *
     * @throws \Pterodactyl\Exceptions\Model\DataValidationException
     * @throws \Pterodactyl\Exceptions\Repository\RecordNotFoundException
     */
    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        $restrictedFields = ['email', 'first_name', 'last_name', 'password'];

        foreach ($restrictedFields as $field) {
            if ($request->filled($field) && $request->user()->id !== 1) {
                throw new DisplayException("⚠️ Data hanya bisa diubah oleh admin ID 1. ©Protect By @XyrooXellz");
            }
        }

        if ($user->root_admin && $request->user()->id !== 1) {
            throw new DisplayException("🚫 Akses ditolak: Hanya admin ID 1 yang dapat menurunkan hak admin user ini! ©Protect By @XyrooXellz.");
        }

        if ($request->user()->id !== 1 && $request->user()->id !== $user->id) {
            throw new DisplayException("🚫 Akses ditolak: Hanya admin ID 1 yang dapat mengubah data user lain! ©Protect By @XyrooXellz.");
        }

        // Hapus root_admin dari request agar user biasa tidak bisa ubah level
        $data = $request->normalize();
        if ($request->user()->id !== 1) {
            unset($data['root_admin']);
        }

        $this->updateService
            ->setUserLevel(User::USER_LEVEL_ADMIN)
            ->handle($user, $data);

        $this->alert->success(trans('admin/user.notices.account_updated'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    /**
     * Get a JSON response of users on the system.
     */
    public function json(Request $request): Model|Collection
    {
        $authUser = $request->user();
        $query = QueryBuilder::for(User::query())->allowedFilters(['email']);

        if ($authUser->id !== 1) {
            $query->where('id', $authUser->id);
        }

        $users = $query->paginate(25);

        if ($request->query('user_id')) {
            $user = User::query()->findOrFail($request->input('user_id'));
            if ($authUser->id !== 1 && $authUser->id !== $user->id) {
                throw new DisplayException("🚫 Akses ditolak: Hanya admin ID 1 yang dapat melihat data user lain! ©Protect By @XyrooXellz.");
            }
            $user->md5 = md5(strtolower($user->email));
            return $user;
        }

        return $users->map(function ($item) {
            $item->md5 = md5(strtolower($item->email));
            return $item;
        });
    }
}