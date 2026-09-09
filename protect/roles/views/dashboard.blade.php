@extends('layouts.admin')
@section('title', 'ZXV Admin Dashboard')
@section('content-header')
    <h1>ZXV Admin Dashboard <small>{{ \Pterodactyl\Support\ZxvRole::label($role) }}</small></h1>
@endsection
@section('content')
<div class="zxv-admin-wrap">
    @if(session('success'))<div class="alert alert-success">{{ session('success') }}</div>@endif
    <div class="row zxv-admin-stats">
        <div class="col-md-3"><div class="zxv-stat"><span>USERS</span><strong>{{ number_format($stats['users']) }}</strong></div></div>
        <div class="col-md-3"><div class="zxv-stat"><span>SERVERS</span><strong>{{ number_format($stats['servers']) }}</strong></div></div>
        <div class="col-md-3"><div class="zxv-stat"><span>NODES</span><strong>{{ number_format($stats['nodes']) }}</strong></div></div>
        <div class="col-md-3"><div class="zxv-stat"><span>SERVER SCRIPTS</span><strong>{{ number_format($stats['scripts']) }}</strong></div></div>
    </div>

    <div class="box zxv-admin-box">
        <div class="box-header with-border"><h3 class="box-title">Create Managed User</h3><span class="zxv-box-note">Role terkontrol</span></div>
        <div class="box-body">
            <form method="post" action="{{ route('admin.zxv.users.create') }}" class="row">
                @csrf
                <div class="col-md-2"><input class="form-control" name="username" placeholder="Username" required></div>
                <div class="col-md-3"><input class="form-control" name="email" type="email" placeholder="Email" required></div>
                <div class="col-md-2"><input class="form-control" name="name_first" placeholder="First name" required></div>
                <div class="col-md-2"><input class="form-control" name="name_last" placeholder="Last name" required></div>
                <div class="col-md-2"><input class="form-control" name="password" type="password" minlength="10" placeholder="Password" required></div>
                <div class="col-md-1"><select class="form-control" name="role"><option value="adp">ADP</option>@if($role === 'ceo')<option value="owner">OWNER</option>@endif</select></div>
                <div class="col-md-12" style="margin-top:10px"><button class="btn btn-primary"><i class="fa fa-user-plus"></i> Create</button></div>
            </form>
        </div>
    </div>

    <div class="box zxv-admin-box">
        <div class="box-header with-border"><h3 class="box-title">Users & Access</h3><span class="zxv-box-note">{{ count($users) }} loaded</span></div>
        <div class="box-body table-responsive">
            <table class="table table-hover zxv-table">
                <thead><tr><th>User</th><th>Role</th><th>Servers</th><th>Access</th><th>Update</th></tr></thead>
                <tbody>
                @foreach($users as $user)
                    @php($userRole = $roles[$user->id] ?? 'user')
                    <tr>
                        <td><strong>{{ $user->username }}</strong><small>{{ $user->email }}</small></td>
                        <td><span class="label label-primary">{{ strtoupper($userRole) }}</span></td>
                        <td>{{ number_format((int) $user->servers_count) }}</td>
                        <td>{{ $userRole === 'user' ? 'Panel user' : ($userRole === 'adp' ? 'Create Server' : ($userRole === 'owner' ? 'Dashboard + ADP' : 'Full Dashboard')) }}</td>
                        <td>
                            @if((int)$user->id !== 1 && \Pterodactyl\Support\ZxvRole::canTouchUser($user, Auth::user()))
                            <form method="post" action="{{ route('admin.zxv.roles') }}" class="form-inline">
                                @csrf
                                <input type="hidden" name="user_id" value="{{ $user->id }}">
                                <select class="form-control input-sm" name="role">
                                    <option value="user" @selected($userRole === 'user')>USER</option>
                                    <option value="adp" @selected($userRole === 'adp')>ADP</option>
                                    @if($role === 'ceo')<option value="owner" @selected($userRole === 'owner')>OWNER</option>@endif
                                </select>
                                <button class="btn btn-default btn-sm">Save</button>
                            </form>
                            @endif
                        </td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    </div>

    <div class="box zxv-admin-box">
        <div class="box-header with-border"><h3 class="box-title">All Server Scripts</h3><span class="zxv-box-note">Startup script per server</span></div>
        <div class="box-body table-responsive">
            <table class="table table-hover zxv-table">
                <thead><tr><th>Server</th><th>Owner</th><th>Egg</th><th>Startup Script</th><th>Action</th></tr></thead>
                <tbody>
                @foreach($servers as $server)
                    <tr>
                        <td><strong>{{ $server->name }}</strong><small>{{ $server->uuid }}</small></td>
                        <td>{{ optional($server->owner)->username ?: 'Unknown' }}</td>
                        <td>{{ optional($server->egg)->name ?: 'Unknown' }}</td>
                        <td><code class="zxv-script-preview">{{ \Illuminate\Support\Str::limit((string)$server->startup, 120) }}</code></td>
                        <td><a class="btn btn-primary btn-sm" href="{{ route('admin.zxv.server.script.download', $server->id) }}"><i class="fa fa-download"></i> Download Script</a></td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    </div>

    <div class="box zxv-admin-box">
        <div class="box-header with-border"><h3 class="box-title">Server Script History</h3><span class="zxv-box-note">Per-server SHA-256 snapshots</span></div>
        <div class="box-body table-responsive">
            <table class="table table-hover zxv-table">
                <thead><tr><th>Server</th><th>Owner</th><th>Hash</th><th>Captured</th><th>Action</th></tr></thead>
                <tbody>
                @foreach($history as $item)
                    <tr>
                        <td><strong>{{ $item->server_name }}</strong><small>ID {{ $item->server_id }}</small></td>
                        <td>{{ $item->owner_username ?: 'Unknown' }}</td>
                        <td><code>{{ substr($item->script_hash, 0, 16) }}</code></td>
                        <td>{{ $item->captured_at }}</td>
                        <td><a class="btn btn-default btn-sm" href="{{ route('admin.zxv.script.history.download', $item->id) }}"><i class="fa fa-download"></i> Download</a></td>
                    </tr>
                @endforeach
                </tbody>
            </table>
        </div>
    </div>
</div>
@endsection
