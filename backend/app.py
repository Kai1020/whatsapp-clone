import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_socketio import SocketIO, emit
from models import db, User, Message, Friendship, FriendRequest

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'whatsapp_clone_super_secret')
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'whatsapp_jwt_secret')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///whatsapp.db')
if app.config['SQLALCHEMY_DATABASE_URI'].startswith("postgres://"):
    app.config['SQLALCHEMY_DATABASE_URI'] = app.config['SQLALCHEMY_DATABASE_URI'].replace("postgres://", "postgresql://", 1)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

CORS(app)
db.init_app(app)
jwt = JWTManager(app)
socketio = SocketIO(app, cors_allowed_origins="*")

# In-memory mapping of user IDs to stringified socket session IDs
user_sockets = {}

@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({"msg": "Username and password required"}), 400
        
    if User.query.filter_by(username=username).first():
        return jsonify({"msg": "Username already exists"}), 409
        
    new_user = User(username=username)
    new_user.set_password(password)
    db.session.add(new_user)
    db.session.commit()
    
    return jsonify({"msg": "User created successfully"}), 201

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    user = User.query.filter_by(username=username).first()
    if not user or not user.check_password(password):
        return jsonify({"msg": "Invalid username or password"}), 401
        
    access_token = create_access_token(identity=str(user.id))
    return jsonify(access_token=access_token, user_id=user.id, username=user.username), 200

@app.route('/api/users', methods=['GET'])
@jwt_required()
def get_users():
    current_user_id = int(get_jwt_identity())
    
    # Get all friend IDs where status is accepted
    friendships = Friendship.query.filter_by(user_id=current_user_id).all()
    friend_ids = [f.friend_id for f in friendships]
    
    # Fetch user objects for those friends
    friends = User.query.filter(User.id.in_(friend_ids)).all()
    user_list = [{"id": u.id, "username": u.username} for u in friends]
    
    return jsonify(user_list), 200

@app.route('/api/users/search', methods=['GET'])
@jwt_required()
def search_users():
    current_user_id = int(get_jwt_identity())
    query = request.args.get('q', '').lower()
    
    if not query:
        return jsonify([]), 200
        
    # Find users matching query, exclude self
    users = User.query.filter(
        User.username.ilike(f'%{query}%'),
        User.id != current_user_id
    ).all()
    
    # Get current user's friendships and pending requests to filter/annotate results
    friendships = Friendship.query.filter_by(user_id=current_user_id).all()
    friend_ids = {f.friend_id for f in friendships}
    
    sent_requests = FriendRequest.query.filter_by(sender_id=current_user_id, status='pending').all()
    sent_request_ids = {r.receiver_id for r in sent_requests}
    
    results = []
    for u in users:
        status = 'none'
        if u.id in friend_ids:
            status = 'friends'
        elif u.id in sent_request_ids:
            status = 'request_sent'
            
        results.append({
            "id": u.id,
            "username": u.username,
            "status": status
        })
        
    return jsonify(results), 200

@app.route('/api/friends/request', methods=['POST'])
@jwt_required()
def send_friend_request():
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    target_user_id = data.get('target_user_id')
    
    if not target_user_id:
        return jsonify({"msg": "target_user_id required"}), 400
        
    if current_user_id == target_user_id:
        return jsonify({"msg": "Cannot send request to yourself"}), 400
        
    # Check if already friends
    if Friendship.query.filter_by(user_id=current_user_id, friend_id=target_user_id).first():
        return jsonify({"msg": "Already friends"}), 400
        
    # Check if request already pending
    existing_req = FriendRequest.query.filter_by(
        sender_id=current_user_id, 
        receiver_id=target_user_id,
        status='pending'
    ).first()
    
    if existing_req:
        return jsonify({"msg": "Request already sent"}), 400
        
    new_request = FriendRequest(sender_id=current_user_id, receiver_id=target_user_id)
    db.session.add(new_request)
    db.session.commit()
    
    return jsonify({"msg": "Request sent successfully"}), 201

@app.route('/api/friends/requests', methods=['GET'])
@jwt_required()
def get_friend_requests():
    current_user_id = int(get_jwt_identity())
    
    requests = FriendRequest.query.filter_by(receiver_id=current_user_id, status='pending').all()
    
    request_list = []
    for req in requests:
        request_list.append({
            "id": req.id,
            "sender_id": req.sender_id,
            "sender_username": req.sender.username,
            "created_at": req.created_at.isoformat()
        })
        
    return jsonify(request_list), 200

@app.route('/api/friends/accept', methods=['POST'])
@jwt_required()
def accept_friend_request():
    current_user_id = int(get_jwt_identity())
    data = request.get_json()
    request_id = data.get('request_id')
    
    if not request_id:
        return jsonify({"msg": "request_id required"}), 400
        
    friend_req = FriendRequest.query.get(request_id)
    
    if not friend_req or friend_req.receiver_id != current_user_id or friend_req.status != 'pending':
        return jsonify({"msg": "Invalid request"}), 400
        
    # Update request status
    friend_req.status = 'accepted'
    
    # Create friendship bonds in both directions
    bond1 = Friendship(user_id=current_user_id, friend_id=friend_req.sender_id)
    bond2 = Friendship(user_id=friend_req.sender_id, friend_id=current_user_id)
    
    db.session.add(bond1)
    db.session.add(bond2)
    db.session.commit()
    
    return jsonify({"msg": "Friend request accepted"}), 200

@app.route('/api/messages/<int:other_user_id>', methods=['GET'])
@jwt_required()
def get_messages(other_user_id):
    current_user_id = int(get_jwt_identity())
    
    messages = Message.query.filter(
        ((Message.sender_id == current_user_id) & (Message.receiver_id == other_user_id)) |
        ((Message.sender_id == other_user_id) & (Message.receiver_id == current_user_id))
    ).order_by(Message.timestamp.asc()).all()
    
    return jsonify([msg.to_dict() for msg in messages]), 200

@socketio.on('connect')
def handle_connect():
    print(f"Client connected: {request.sid}")

@socketio.on('disconnect')
def handle_disconnect():
    print(f"Client disconnected: {request.sid}")
    # Remove user from active sockets
    for user_id, sid in list(user_sockets.items()):
        if sid == request.sid:
            del user_sockets[user_id]
            break

@socketio.on('authenticate')
def handle_authenticate(data):
    user_id = data.get('user_id')
    if user_id:
        user_sockets[str(user_id)] = request.sid
        print(f"User {user_id} authenticated with session {request.sid}")

@socketio.on('send_message')
def handle_send_message(data):
    sender_id = data.get('sender_id')
    receiver_id = data.get('receiver_id')
    content = data.get('content')
    
    if not all([sender_id, receiver_id, content]):
        return
        
    # Save to DB
    with app.app_context():
        new_msg = Message(sender_id=sender_id, receiver_id=receiver_id, content=content)
        db.session.add(new_msg)
        db.session.commit()
        msg_data = new_msg.to_dict()
    
    # Emit to receiver if online
    receiver_sid = user_sockets.get(str(receiver_id))
    if receiver_sid:
        emit('receive_message', msg_data, room=receiver_sid)
        
    # Emit back to sender as well (for confirmation)
    emit('message_sent', msg_data, room=request.sid)

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    socketio.run(app, debug=True, host='0.0.0.0', port=5000, allow_unsafe_werkzeug=True)
