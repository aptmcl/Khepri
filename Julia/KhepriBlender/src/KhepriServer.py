import sys
def warn(msg):
    print(msg, file=sys.stderr)
    sys.stderr.flush()

import math
import time
import os.path
#from math import *
from typing import List, Tuple, NewType
import struct
from functools import partial

Size = NewType('Size', int)
Id = Size
MatId = Size
Float3 = Tuple[float,float,float]
RGB = Tuple[float,float,float]
RGBA = Tuple[float,float,float,float]

#######################################
# Communication
#Python provides sendall but not recvall
def recvall(sock, count):
    buf = b''
    while count:
        newbuf = sock.recv(count)
        if not newbuf: return None
        buf += newbuf
        count -= len(newbuf)
    return buf

def dump_exception(ex, conn):
    warn('Dumping exception!!!')
    warn("".join(traceback.TracebackException.from_exception(ex).format()))
    w_str("".join(traceback.TracebackException.from_exception(ex).format()), conn)

def r_struct(s, conn):
    return s.unpack(recvall(conn, s.size))[0]

def w_struct(s, e, conn):
    conn.sendall(s.pack(e))

def r_tuple_struct(s, conn):
    return s.unpack(recvall(conn, s.size))

def w_tuple_struct(s, e, conn):
    conn.sendall(s.pack(*e))

def r_list_struct(s, conn):
    n = r_int(conn)
    es = []
    for i in range(n):
        es.append(r_struct(s, conn))
    return es

def w_list_struct(s, es, conn):
    w_int(len(es), conn)
    for e in es:
        w_struct(s, e, conn)

int_struct = struct.Struct('i')
float_struct = struct.Struct('d')
byte_struct = struct.Struct('1B')

def w_None(e, conn)->None:
    w_struct(byte_struct, 0, conn)

def r_bool(conn)->bool:
    return r_struct(byte_struct, conn) == 1
def w_bool(b:bool, conn)->None:
    w_struct(byte_struct, 1 if b else 0, conn)

r_int = partial(r_struct, int_struct)
w_int = partial(w_struct, int_struct)

r_float = partial(r_struct, float_struct)
w_float = partial(w_struct, float_struct)

r_Size = partial(r_struct, int_struct)
w_Size = partial(w_struct, int_struct)

def r_str(conn)->str:
    size = 0
    shift = 0
    byte = 0x80
    while byte & 0x80:
        try:
            byte = ord(conn.recv(1))
        except TypeError:
            raise IOError('Buffer empty')
        size |= (byte & 0x7f) << shift
        shift += 7
    return recvall(conn, size).decode('utf-8')

def w_str(s:str, conn):
    size = len(s)
    array = bytearray()
    while True:
        byte = size & 0x7f
        size >>= 7
        if size:
            array.append(byte | 0x80)
        else:
            array.append(byte)
            break
    conn.send(array)
    conn.sendall(s.encode('utf-8'))

float3_struct = struct.Struct('3d')
r_float3 = partial(r_tuple_struct, float3_struct)
w_float3 = partial(w_tuple_struct, float3_struct)

def r_List(f, conn):
    n = r_int(conn)
    es = []
    for i in range(n):
        es.append(f(conn))
    return es

def w_List(f, es, conn):
    w_int(len(es), conn)
    for e in es:
        f(e, conn)

r_List_int = partial(r_List, r_int)
w_List_int = partial(w_List, w_int)

r_List_Size = partial(r_List, r_Size)
w_List_Size = partial(w_List, w_Size)

r_List_float = partial(r_List, r_float)
w_List_float = partial(w_List, w_float)

r_List_float3 = partial(r_List, r_float3)
w_List_float3 = partial(w_List, w_float3)

r_List_List_int = partial(r_List, r_List_int)
w_List_List_int = partial(w_List, w_List_int)

int_int_struct = struct.Struct('2i')
r_Tint_intT = partial(r_tuple_struct, int_int_struct)
w_Tint_intT = partial(w_tuple_struct, int_int_struct)

r_List_Tint_intT = partial(r_List, r_Tint_intT)
w_List_Tint_intT = partial(w_List, w_Tint_intT)

##############################################################
# For automatic generation of serialize/deserialize code
import inspect

def is_tuple_type(t)->bool:
    return hasattr(t, '__origin__') and t.__origin__ is tuple

def tuple_elements_type(t):
    return t.__args__

def is_list_type(t)->bool:
    return hasattr(t, '__origin__') and t.__origin__ is list

def list_element_type(t):
    return t.__args__[0]

def method_name_from_type(t)->str:
    if is_list_type(t):
        return "List_" + method_name_from_type(list_element_type(t))
    elif is_tuple_type(t):
        return "T" + '_'.join([method_name_from_type(pt) for pt in tuple_elements_type(t)]) + 'T'
    elif t is None:
        return "None"
    else:
        return t.__name__

def deserialize_parameter(c:str, t)->str:
    if is_tuple_type(t):
        return '(' + ','.join([deserialize_parameter(c, pt) for pt in tuple_elements_type(t)]) + ',)'
    else:
        return f"r_{method_name_from_type(t)}({c})"

def serialize_return(c:str, t, e:str)->str:
    ok_prefix = f"w_struct(byte_struct, 0, {c})"
    if is_tuple_type(t):
        writes = '; '.join([f"w_{method_name_from_type(pt)}(__r[{i}], {c})"
                            for i, pt in enumerate(tuple_elements_type(t))])
        return f"__r = {e}; {ok_prefix}; {writes}"
    else:
        return f"__r = {e}; {ok_prefix}; w_{method_name_from_type(t)}(__r, {c})"

def serialize_error(c:str, t, e:str)->str:
    return f"w_struct(byte_struct, 1, {c}); dump_exception({e}, {c})"

def try_serialize(c:str, t, e:str)->str:
    return f"""
    try:
        {e}
    except Exception as __ex:
        warn('RMI Error!!!!')
        warn("".join(traceback.TracebackException.from_exception(__ex).format()))
        warn('End of RMI Error.  I will attempt to serialize it.')
        {serialize_error(c, t, "__ex")}"""

def generate_rmi(f):
    c = 'c'
    name = f.__name__
    sig = inspect.signature(f)
    rt = sig.return_annotation
    pts = [p.annotation for p in sig.parameters.values()]
    des_pts = ','.join([deserialize_parameter(c, p) for p in pts])
    body = try_serialize(c, rt, serialize_return(c, rt, f"{name}({des_pts})"))
    dict = globals()
    rmi_name = f"rmi_{name}"
    rmi_f = f"def {rmi_name}({c}):{body}"
    #warn(rmi_f)
    exec(rmi_f, dict)
    return dict[rmi_name]

##############################################################
# There are two options: either I am the server, or I am the client.

i_am_the_server = True

##############################################################
# Socket server
import socket

backend_port = 12345
socket_server = None
connection = None
current_action = None
min_wait_time = 0.1
max_wait_time = 0.2
max_repeated = 1000

def set_backend_port(n:int)->int:
    global backend_port
    backend_port = n
    return backend_port


def set_max_repeated(n:int)->int:
    global max_repeated
    prev = max_repeated
    max_repeated = n
    return prev

class FrameIO:
    """Proxy that reads from frame data and buffers writes for the response frame."""
    def __init__(self, frame_data, conn):
        self._read_buf = frame_data
        self._read_pos = 0
        self._write_buf = bytearray()
        self._conn = conn

    def recv(self, count):
        end = self._read_pos + count
        data = self._read_buf[self._read_pos:end]
        self._read_pos = end
        return data

    def sendall(self, data):
        self._write_buf.extend(data)

    def send(self, data):
        self._write_buf.extend(data)
        return len(data)

    def flush_response(self):
        resp = bytes(self._write_buf)
        self._conn.sendall(int_struct.pack(len(resp)))
        self._conn.sendall(resp)

def read_frame(conn):
    raw_len = recvall(conn, 4)
    if raw_len is None:
        return None
    frame_len = int_struct.unpack(raw_len)[0]
    frame_data = recvall(conn, frame_len)
    if frame_data is None:
        return None
    frame_io = FrameIO(frame_data, conn)
    opcode = r_int(frame_io)
    return (opcode, frame_io)

def execute_read_and_repeat(op, frame_io, conn):
    count = 0
    while True:
        if op == -1:
            return False
        execute(op, frame_io)
        count += 1
        if count > max_repeated:
            return False
        conn.settimeout(max_wait_time)
        try:
            result = read_frame(conn)
            if result is None:
                op = -1
            else:
                op, frame_io = result
        except socket.timeout:
            break
        finally:
            conn.settimeout(None)
    return True


operations = []

def provide_operation(name:str, canonical:str)->int:
    warn(f"Requested operation |{name}| [{canonical}] -> {globals()[name]}")
    operations.append(generate_rmi(globals()[name]))
    return len(operations) - 1

# The first operation is the operation that makes operations available
operations.append(generate_rmi(provide_operation))

def execute(op, frame_io):
    operations[op](frame_io)
    frame_io.flush_response()

def wait_for_connection():
    global current_action
    warn('Waiting for connection...')
    current_action = accept_client if i_am_the_server else start_client

import traceback
def execute_current_action():
    #warn(f"Execute {current_action}")
    try:
        current_action()
    except Exception as ex:
        traceback.print_exc()
        #warn('Resetting socket server.')
        warn('Killing socket server.')
        if connection:
            connection.close()
        wait_for_connection()
    finally:
        return max_wait_time # timer

def start_server():
    global socket_server
    socket_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    socket_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    socket_server.bind(('localhost', backend_port))
    socket_server.settimeout(max_wait_time)
    socket_server.listen(5)
    wait_for_connection()

counter_accept_attempts = 1
def accept_client():
    global counter_accept_attempts
    global connection
    global current_action
    try:
        #warn(f"Is anybody out there? (attempt {counter_accept_attempts})")
        connection, client_address = socket_server.accept()
        warn('Connection established.')
        current_action = handle_client
    except socket.timeout:
        counter_accept_attempts += 1
        #warn('It does not seem that there is.')
        # keep trying
        pass
    except Exception as ex:
        warn('Something bad happened!')
        traceback.print_exc()
        #warn('Resetting socket server.')

def handle_client():
    conn = connection
    conn.settimeout(min_wait_time)
    try:
        result = read_frame(conn)
    except socket.timeout:
        return
    finally:
        conn.settimeout(None)
    if result is None:
        warn("Connection terminated.")
        wait_for_connection()
    else:
        op, frame_io = result
        execute_read_and_repeat(op, frame_io, conn)

################################################################################
# Alternatively, instead of starting the socket server on the Python side, 
# we can start as a client.
backend_name = None

def start_client():
    global connection
    global backend_name
    global current_action
    connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    connection.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        connection.connect(('localhost', backend_port))
        connection.settimeout(max_wait_time)
        w_str(backend_name, connection)
        current_action = handle_client
        return True
    except socket.error:
        warn("Couldn't connect to server.")
        connection.close()
        return False

def init_client_server(name, server_port):
    global i_am_the_server
    global current_action
    global backend_name
    backend_name = name
    i_am_the_server = server_port > 0
    if i_am_the_server:
        set_backend_port(server_port)
        current_action = start_server
    else:
        set_backend_port(12345)
        current_action = start_client

################################################################################
# Now, the backend-specific part. First, import this file:
"""
from KhepriServer import set_backend_port, execute_current_action, Size, r_float3, w_float3
"""

# Then, define your own types, serializers/deserializers, and operations.
# E.g., for Blender, we might have:
"""
from mathutils import Vector, Matrix
Point3d = Vector
Vector3d = Vector
Id = Size
MatId = Size

def r_Vector(conn)->Vector:
    return Vector(r_float3(conn))

def w_Vector(e:Vector, conn)->None:
    w_float3((e.x, e.y, e.z))

e_Vector = e_float3

r_List_Vector = partial(r_List, r_Vector)
w_List_Vector = partial(w_List, w_Vector)
e_List_Vector = e_List

r_List_List_Vector = partial(r_List, r_List_Vector)
w_List_List_Vector = partial(w_List, w_List_Vector)
e_List_List_Vector = e_List
...

def circle(c:Point3d, v:Vector3d, r:float, mat:MatId)->Id:
    ...
"""

# To run as a server (the default), define the listening port:
"""
init_client_server("FooBackend", 12345)
"""
# To run as a client, specify a listening port of 0 (or less):
"""
init_client_server("FooBackend", 0)
"""

# We then either run in batch mode:
"""
while True:
    execute_current_action()
"""
# or we use a timer:
"""
backend.timers.register(execute_current_action)
"""
# or an idle event handler
"""
backend.on_idle_event(execute_current_action)
"""
