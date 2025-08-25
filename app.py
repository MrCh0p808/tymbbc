# app.py

from flask import Flask, render_template, request, session, redirect, url_for
from flask_socketio import SocketIO, join_room, leave_room, send

app = Flask(__name__)
# A secret key is required for session management
app.config['SECRET_KEY'] = 'your-super-secret-key'
socketio = SocketIO(app)

# In-memory database to store chat rooms and messages
# In a production app, you'd use a real database (e.g., Redis, PostgreSQL)
rooms = {}

# --- HTTP Routes ---

@app.route('/', methods=['GET', 'POST'])
def index():
    """
    The inbox/login screen. A user provides their name and a room code.
    """
    session.clear() # Clear previous session data
    if request.method == 'POST':
        name = request.form.get('name')
        code = request.form.get('code')

        if not name or not code:
            return render_template('index.html', error='Please enter a name and room code.', code=code, name=name)

        # A user cannot join a room that doesn't exist from the chat screen
        # But for the inbox, we allow creating rooms
        if code not in rooms:
            rooms[code] = {'members': 0, 'messages': []}

        session['room'] = code
        session['name'] = name
        return redirect(url_for('chat'))

    return render_template('index.html')

@app.route('/chat')
def chat():
    """
    The main chat screen. Redirects to inbox if user is not logged in.
    """
    room = session.get('room')
    name = session.get('name')

    if not room or not name or room not in rooms:
        return redirect(url_for('index'))

    # The chat history is passed to the template to render previous messages
    return render_template('chat.html', room=room, name=name, messages=rooms[room]['messages'])

# --- WebSocket Events ---

@socketio.on('connect')
def connect():
    """
    Handles a new user connecting to the chat.
    The user joins a room and we broadcast their arrival.
    """
    room = session.get('room')
    name = session.get('name')
    if not room or not name:
        return

    if room not in rooms:
        # This is a safeguard; user should be redirected by the HTTP route
        leave_room(room)
        return

    join_room(room)
    # Broadcast a "has joined" message to everyone in the room
    send({'name': name, 'message': 'has entered the room.'}, to=room)
    rooms[room]['members'] += 1
    print(f'{name} joined room {room}')

@socketio.on('disconnect')
def disconnect():
    """
    Handles a user disconnecting. We remove them from the room.
    If the room is empty, we delete it and its message history.
    """
    room = session.get('room')
    name = session.get('name')
    leave_room(room)

    if room in rooms:
        rooms[room]['members'] -= 1
        # If the last member leaves, the room and its chat history are deleted
        if rooms[room]['members'] <= 0:
            del rooms[room]
            print(f"Room {room} is empty and has been closed.")

        # Broadcast a "has left" message
        send({'name': name, 'message': 'has left the room.'}, to=room)
        print(f'{name} has left room {room}')


@socketio.on('message')
def message(data):
    """
    Receives a new message from a client and broadcasts it to the room.
    """
    room = session.get('room')
    if room not in rooms:
        return

    # Create the message content to be sent
    content = {
        'name': session.get('name'),
        'message': data['data']
    }
    send(content, to=room)
    # Add the new message to our in-memory history
    rooms[room]['messages'].append(content)
    print(f'{session.get("name")} said in {room}: {data["data"]}')


if __name__ == '__main__':
    # For local testing
    socketio.run(app, debug=True)
